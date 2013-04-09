#!/usr/bin/env ruby
# coding: utf-8

# require 'bundler/setup'
require 'twitter'
require 'open-uri'
require 'mongoid'
require 'mechanize'
require 'parallel'
require 'timeout'
require 'benchmark'
require 'uri'

require './configure'
require './webpage'
require './bayes'

Twitter.configure do |config|
    config.consumer_key       = ENV['CONSUMER_KEY']
    config.consumer_secret    = ENV['CONSUMER_SECRET']
    config.oauth_token        = ENV['OAUTH_TOKEN']
    config.oauth_token_secret = ENV['OAUTH_TOKEN_SECRET']
end

Mongoid.load!('mongoid.yml')

class TempUrl
    include Mongoid::Document
    field :url, type: String
    field :timestamps_twitter, type: Array
end

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
    field :timestamps_twitter, type: Array
    field :counting_twitter, type: Integer
    field :counted_twitter, type: Integer
    field :count_all_twitter, type: Integer
    
    field :count_all_facebook, type: Integer

    # はてなブックマークの数を数える
    field :count_recent_hatena, type: Integer
    field :count_all_hatena, type: Integer
end

class NGSite
    include Mongoid::Document
    field :domain, type: String
end

class WhiteSite
    include Mongoid::Document
    field :domain, type: String
end

def get_urls(size)
    urls = []
    TempUrl.each do |url|
        obj = Hash.new
        obj[:url] = url.url
        obj[:timestamps_twitter] = url.timestamps_twitter
        urls << obj
        url.delete
        break if urls.size >= size
        break if TempUrl.count < size/10
    end
    urls
end

def video?(url)
    return true if url.url.include?('youtube.com')
    return true if url.url.include?('www.nicovideo.jp')
    nil
end

def app?(url)
    return true if url.url.include?('itunes.apple.com')
    return true if url.url.include?('play.google.com')
    nil
end

def amazon?(url)
    return true if url.url.include?('amazon.co.jp')
    nil
end

def add(webpage, url)
    q = Url.where(url: webpage.url)
    if q.exists?
        q.first.push_all(:timestamps_twitter, url[:timestamps_twitter])
        q.first.inc(:counting_twitter, url[:timestamps_twitter].size)
    else
        q.create(title: webpage.title,
                 title_array: webpage.title_array,
                 body: webpage.body,
                 category: MyClassifier.new.classify(nouns(webpage.body).join(' ')),
                 timestamps_twitter: url[:timestamps_twitter],
                 counting_twitter: url[:timestamps_twitter].size)
    end
end

def add_without_body(webpage, url)
    q = Url.where(url: webpage.url)
    if q.exists?
        q.first.push_all(:timestamps_twitter, url[:timestamps_twitter])
        q.first.inc(:counting_twitter, url[:timestamps_twitter].size)
    else
        q.create(title: webpage.title,
                 image_url: webpage.image_url,
                 timestamps_twitter: url[:timestamps_twitter],
                 counting_twitter: url[:timestamps_twitter].size)
    end
end

urls = get_urls(1500)
Parallel.each(urls, in_threads: 30) do |url|
    webpage = Webpage.new(url[:url])

    # URLかタイトルがないと無視
    next if (not webpage.url) or (not webpage.title)

    if video?(webpage) or app?(webpage) or amazon?(webpage)
        add_without_body(webpage, url)
    else
        # もしURLが"http://news.google.com/"みたいなトップページふうだったら無視
        uri = URI(webpage.url)
        next if (uri.path.size < 2) and (not uri.query) and (not uri.fragment)

        # Whitelistに登録されて"いなかったら"skip
        skip = true
        WhiteSite.each do |site|
            if webpage.url.include?(site.domain)
                skip = nil
                break
            end
        end
        next if skip
        # NGSiteに登録されているhostだったら無視する
        skip = nil
        NGSite.each do |site|
            if webpage.url.include?(site.domain)
                skip = true
                break
            end
        end
        next if skip

        # ここまでたどり着いた君は追加すべき優秀なURLだ！
        add(webpage, url)
    end
end
