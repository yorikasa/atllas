# coding: utf-8

require 'classifier'
require 'mongoid'
require 'open-uri'
require 'nkf'
require 'readability'
require 'mechanize'
require 'MeCab'

require './configure'

EXCEPTION = /^[!-\/:.,?\[\]{}@#\$%^&*()_+=\\|'";<>~`「」『』、。〜ーw★☆█♪\^0-9]+?$/

class Trainer
    include Mongoid::Document
    field :category, type: String
    field :body, type: String
end

class MyClassifier
    def initialize
        begin
            @classifier = nil
            File.open("classifier", "r") {|f| @classifier = Marshal.load(f)}
        rescue
            # 動画 (YouTube, ニコニコ, Ustream, etc)", "画像" は別枠でやる
            @categories = %w(society politic economy sport world tech science entertainment 2ch)
            @classifier = Classifier::Bayes.new(*@categories)
        end
    end

    def classify(string)
        @classifier.classify(string)
    end

    def classifications(string)
        @classifier.classifications(string)
    end

    def train
        Trainer.each do |t|
            @classifier.train(t.category, t.body)
        end
        File.open("classifier", "wb") {|f| Marshal.dump(@classifier, f)}
    end
end

def nouns(string)
    m = MeCab::Tagger.new
    node = m.parseToNode(NKF.nkf('-Z0Z1w', string.chomp.downcase))
    nouns = []
    while(node.next)
        if node.feature.force_encoding('utf-8').split(',')[0] == "名詞"
            word = node.surface.force_encoding('utf-8')
            # 記号だけが続く文字列は、それが「名詞」と判断されていようが無視する
            unless word =~ EXCEPTION
                nouns << word if word.length > 1
            end
        end
        node = node.next
    end
    nouns
rescue
    return []
end
