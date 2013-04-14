#!/usr/bin/env ruby
# coding: utf-8

# individual pages をつくるために、キャッシュするために実行するスクリプト。
# 1時間に1回くらい実行するのかなあ。未定。

require 'mongoid'
require 'uri'
require 'benchmark'
require 'thread'
require './configure'

Mongoid.load!('mongoid.yml')

class Url
    include Mongoid::Document
    include Mongoid::Timestamps
    
    field :url, type: String
    field :image_url, type: String
    field :title, type: String
    field :title_array, type: Array
    field :body, type: String
    field :category, type: String

    # Twitterでの言及数を数える
    field :tweets, type: Array
    field :counting_twitter, type: Integer
    field :counted_twitter, type: Integer
    field :count_all_twitter, type: Integer
    
    field :count_all_facebook, type: Integer

    # はてなブックマークの数を数える
    field :count_recent_hatena, type: Integer
    field :count_all_hatena, type: Integer
end

def atoh(array)
    return nil if not array
    hash = Hash.new(0)
    array.each do |e|
        hash[e] += 1
    end
    hash
end

def normalize(hash)
    return nil if not hash
    norm = 0.0
    hash.each do |word, freq|
        norm += freq.to_f**2
    end
    norm = Math.sqrt(norm)
    normalized_hash = {}
    hash.each{|w,f| normalized_hash[w] = f/norm}
    normalized_hash
end

def cosine_sim(doc1, doc2)
    return 0 if (not doc1) or (not doc2)

    similarity = 0.0
    doc1.each do |term, freq|
        doc2.each do |ut, uf|
            if term.to_s.downcase == ut.to_s.downcase
                similarity += freq*uf.to_f
            end
        end
    end
    similarity
end

def sim(url1, url2)
    cosine_sim(normalize(atoh(url1.title_array)), normalize(atoh(url2.title_array)))
end


def cache(from, to)
    puts Url.where(created_at: (Time.now-3600*to.to_i..Time.now-3600*from.to_i)).count
    Url.where(created_at: (Time.now-3600*to.to_i..Time.now-3600*from.to_i)).desc(:counting_twitter).limit(1000).no_timeout.each do |subj|
        puts Benchmark.measure{
            thost = URI(subj[:url]).host
            ttime = subj[:created_at]
            Url.where(created_at: (ttime-3600*6..ttime+3600*6)).desc(:counting_twitter).limit(100).no_timeout.each do |obj|
                next if (obj[:counting_twitter] < 2) or (obj[:counted_twitter] < 5)
                next if thost == URI(obj[:url]).host
                if sim(subj, obj) > 0.3
                    subj.push(:related, obj.id)
                end
            end
        }
    end
end


puts told = Time.now

threads = []
6.times do |i|
    threads << Thread.new{ cache(i, i+1) }
end
threads.each{|t|t.join}

puts Time.now
puts "#{(Time.now-told)/60} min"
