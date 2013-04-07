#!/usr/bin/env ruby
# coding: utf-8

# Webサイト上で表示される記事は、6AM, 6PMに更新されるようにしている。
# そのために、最新のTwitterでの言及回数を`:counting_twitter`に保存し、
# 6AM/PMになったときには本プログラム (count_reset.rb) が動いてそのデータを
# `:counted_twitter`へと移し、同時に`:count_all_twitter`にも加える。
# 以上の働きによって、Webサイトでは`:counted_twitter`を使って表示を行える。
# つまり、このプログラムは6AM/PMにcronで実行されるようになっている。

require 'mongoid'
require 'cgi'
require 'open-uri'

require './configure'
Mongoid.load!('mongoid.yml')

class Url
    include Mongoid::Document
    field :url, type: String
    field :image_url, type: String
    field :title, type: String
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

def count_move_twitter(url)
    # countの移行
    return nil if url.counting_twitter == 0
    url.set(:counted_twitter, url.counting_twitter)
    if url.count_all_twitter
        url.set(:count_all_twitter, url.counting_twitter + url.count_all_twitter)
    else
        url.set(:count_all_twitter, url.counting_twitter)
    end
    url.set(:counting_twitter, 0)

    # データ量を減らすために、`:count_all_twitter`が1のURLは捨てる
    if url[:count_all_twitter] == 1
        url.delete
        return nil
    end
    # うまくいったときは nil 以外の何かを返す
    ""
end

def count_move_hatena(url)
    head = "http://api.b.st-hatena.com/entry.count"
    hatena_count = open("#{head}?url=#{CGI.escape(url.url)}").read.to_i

    # url.set(:counted_hatena, hatena_count)
    if url.count_all_hatena
        old_all = url.count_all_hatena
        url.set(:count_all_hatena, hatena_count)
        url.set(:count_recent_hatena, hatena_count - old_all)
    else
        url.set(:count_all_hatena, hatena_count)
    end
end

Url.each do |url|
    next if not count_move_twitter(url)
    count_move_hatena(url)
end
