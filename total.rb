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

class TempUrl
    include Mongoid::Document
    field :url, type: String
    field :timestamps_twitter, type: Array
end

class Url
    include Mongoid::Document
    field :url, type: String
    field :title, type: String
    field :body, type: String
    field :category, type: String
    field :timestamps_twitter, type: Array

    field :counting_twitter, type: Integer
    field :counted_twitter, type: Integer
    field :count_all_twitter, type: Integer
    field :count_all_facebook, type: Integer
    field :count_all_hatena, type: Integer
end

class NGSite
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

# old = Time.now
# puts "Start: #{old}"

urls = get_urls(1000)
Parallel.each(urls, in_threads: 30) do |url|
    webpage = Webpage.new(url[:url])
    next unless wurl = webpage.url
    next unless webpage.title
    # NGSiteに登録されているhostだったら無視する
    skip = nil
    NGSite.each do |site|
        if webpage.url.include?(site.domain)
            skip = true
            break
        end
    end
    next if skip
    # もしURLが"http://news.google.com/"みたいなトップページふうだったら無視する
    uri = URI(webpage.url)
    next if (uri.path.size < 2) and (not uri.query) and (not uri.fragment)

    q = Url.where(url: wurl)
    if q.exists?
        q.first.push_all(:timestamps_twitter, url[:timestamps_twitter])
        q.first.inc(:counting_twitter, url[:timestamps_twitter].size)
    else
        wtitle = webpage.title
        wbody = webpage.body
        wcategory = MyClassifier.new.classify(nouns(wbody).join(' '))
        q.create(title: wtitle,
                 body: wbody,
                 category: wcategory,
                 timestamps_twitter: url[:timestamps_twitter],
                 counting_twitter: url[:timestamps_twitter].size)
    end
end

# new = Time.now
# puts "End: #{new}"

# puts "Time Elapsed: #{(new-old)/60} min"
# puts "Memory Usage: #{`ps -o rss= -p #{Process.pid}`.to_i}KB"
