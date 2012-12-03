# coding: utf-8

require 'bundler/setup'
require 'twitter'
require 'open-uri'
require 'mongoid'
require 'mechanize'
require 'parallel'
require 'timeout'

require './configure'

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
    field :content, type: String
    field :timestamps_twitter, type: Array

    field :count_recent_twitter, type: Integer
    field :count_all_twitter, type: Integer
    field :count_all_facebook, type: Integer
    field :count_all_hatena, type: Integer
end

def deparam(url)
    url = url.gsub(/[&?]*?utm_.+?=.+?(&|\Z)/, '')
    url = url.gsub(/[&?]*?fr=.+?(&|\Z)/, '')
end    

def fetch(url, limit=20)
    return deparam(url) if limit < 0 or not url

    response = 0
    Timeout::timeout(5) do
        response = Net::HTTP.get_response(URI.parse(url))
    end
    case response
    when Net::HTTPRedirection
        fetch(response['location'], limit-1)
    when Net::HTTPSuccess
        url
    when Net::HTTPBadGateway
        # 良くない処理かもしれないけど、httpsのときBad Gatewayになるので
        url
    else
        nil
    end
rescue Errno::ECONNRESET
    return url
rescue
    nil
end

def get_title(url)
    return nil unless url
    
    agent = Mechanize.new
    agent.user_agent = 'total'
    agent.max_history = 1
    agent.open_timeout   = 5
    agent.read_timeout   = 5

    agent.content_encoding_hooks << lambda{|httpagent,uri,response,body_io|
        valid = /compress|deflate|exi|gzip|identity|pack200-gzip/
        unless valid =~ response['content-encoding']
            response.delete('content-encoding')
        end
    }
    page = agent.get(url)
    if page.class == Mechanize::Page
        page.title.gsub(/[\n\t\r\f]/, "").strip if page.title
    else
        url
    end
rescue => ex
    puts
    error(ex)
    $stderr.puts "title: #{url}"
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
    end
    urls
end

def error(ex)
    puts "-------------------------------------------------------------------#{$count}"
    $stderr.puts "#{ex.class}: #{ex.message}\n #{ex.backtrace}"
end

$count = 0
urls = get_urls(200)

while urls do
    puts "TempUrl: #{TempUrl.count}  Url: #{Url.count}"
    
    Parallel.each(urls, in_threads: 20) do |url|
        full_url = fetch(url[:url])
        title = get_title(full_url) if full_url

        $count += 1
        next unless full_url and title

        q = Url.where(url: full_url)
        if q.exists?
            q.first.push_all(:timestamps_twitter, url[:timestamps_twitter])
        else
            q.create(title: title,
                     timestamps_twitter: url[:timestamps_twitter])
        end
    end
    break if TempUrl.count < 100
    urls = get_urls(300)
end

puts

# total
