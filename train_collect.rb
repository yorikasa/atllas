# coding: utf-8

# Naive Bayesのtrainをさせるためのデータを収集するプログラム。
# 標準入力を受け取り、それを正規化 (半角->全角など) し、DBに貯める。

require 'mongoid'
require 'open-uri'
require 'nkf'
require 'readability'
require 'mechanize'
require 'MeCab'

require './configure'

EXCEPTION = /^[!-\/:.,?\[\]{}@#\$%^&*()_+=\\|'";<>~`「」『』、。〜ーw★☆█♪\^0-9]+?$/
categories = %w(society politic economy sport world tech science entertainment 2ch)

class Trainer
    include Mongoid::Document
    field :category, type: String
    field :body, type: String
end

class TempUrl
    include Mongoid::Document
    field :url, type: String
    field :timestamps_twitter, type: Array
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

def body(url)
    agent = Mechanize.new
    agent.user_agent = 'squid'
    agent.max_history = 1
    agent.open_timeout   = 3
    agent.read_timeout   = 3
    agent.keep_alive = false

    # おまじないみたいな
    agent.content_encoding_hooks << lambda{|httpagent,uri,response,body_io|
        valid = /compress|deflate|exi|gzip|identity|pack200-gzip/
        unless valid =~ response['content-encoding']
            response.delete('content-encoding')
        end
    }
    page = agent.get(url)
    # p page.encoding
    # page = open(url).read.encode('utf-8')# .force_encoding('utf-8')
    body = Readability::Document.new(page.body).content.encode('utf-8')
    body.gsub!(/(<\/?div>|<\/?p>)/,'')
    body.gsub!(/https?:.+?(\s|\Z)/, '')
    body
# rescue
#     return body = ""
end

categories.each do |cat|
    puts "#{cat}: -------"
    urls = []
    while 1
        input = gets.chomp
        break if input.empty?
        urls << input
    end
    urls.each do |url|
        body = nouns(body(url)).join(' ')
        Trainer.create(category: cat, body: body) unless body.empty?
        p body
    end
end
