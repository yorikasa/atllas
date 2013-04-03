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

    field :count_recent_twitter, type: Integer
    field :count_all_twitter, type: Integer
    field :count_all_facebook, type: Integer
    field :count_all_hatena, type: Integer
end

EXCLUDE = /twitter\.com|twitpic\.com|twipple\.jp|yfrog\.com|photozou\.jp|shindanmaker\.com|lockerz\.com|instagram\.com|via\.me|rekkacopy\.com|sns48\.com|550909\.com|twitcasting\.tv|gungho\.jp|notfollow\.me|webken\.net|applica\.jp|twtmanager\.com|otapps\.net|angel-live\.com|194964\.com|furaieki\.net|d2c\.co\.jp|oidn\.info|isop\.co\.jp|tsukasa02\.com|puzzdra\.mobi|yoyakuga\.com|facebook\.com|happymail\.co\.jp|atarijo\.com|pcmax\.jp|uranaitter\.com|shioyakiwa\.blog\.fc2\.com|henchmen\.jp|nubee\.com|madam-sex\.com|justunfollow\.com/i

def get_urls(size)
    urls = []
    TempUrl.each do |url|
        unless EXCLUDE =~ url.url
            obj = Hash.new
            obj[:url] = url.url
            obj[:timestamps_twitter] = url.timestamps_twitter
            urls << obj
        end
        url.delete
        break if urls.size >= size
    end
    urls
end

old = Time.now
puts "Start: #{old}"

urls = get_urls(1000)
Parallel.each(urls, in_threads: 30) do |url|
    webpage = Webpage.new(url[:url])
    next unless wurl = webpage.url
    next if EXCLUDE =~ webpage.url

    q = Url.where(url: wurl)
    if q.exists?
        q.first.push_all(:timestamps_twitter, url[:timestamps_twitter])
        q.first.update_attributes(count_recent_twitter: url[:timestamps_twitter].size)
        q.first.inc(:count_all_twitter, url[:timestamps_twitter].size)
    else
        wtitle = webpage.title
        wbody = webpage.body
        wcategory = MyClassifier.new.classify(nouns(wbody).join(' '))
        q.create(title: wtitle,
                 body: wbody,
                 category: wcategory,
                 timestamps_twitter: url[:timestamps_twitter],
                 count_recent_twitter: url[:timestamps_twitter].size,
                 count_all_twitter: url[:timestamps_twitter].size)
    end
end

new = Time.now
puts "End: #{new}"

puts "Time Elapsed: #{(new-old)/60} min"
puts "Memory Usage: #{`ps -o rss= -p #{Process.pid}`.to_i}KB"
