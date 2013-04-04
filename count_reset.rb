#!/usr/bin/env ruby
# coding: utf-8

# Webサイト上で表示される記事は、6AM, 6PMに更新されるようにしている。
# そのために、最新のTwitterでの言及回数を`:counting_twitter`に保存し、
# 6AM/PMになったときには本プログラム (count_reset.rb) が動いてそのデータを
# `:counted_twitter`へと移し、同時に`:count_all_twitter`にも加える。
# 以上の働きによって、Webサイトでは`:counted_twitter`を使って表示を行える。
# つまり、このプログラムは6AM/PMにcronで実行されるようになっている。

require 'mongoid'

require './configure'

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

Url.each do |url|
    next if url.counting_twitter == 0
    url.set(:counted_twitter, url.counting_twitter)
    if url.count_all_twitter
        url.set(:count_all_twitter, url.counting_twitter + url.count_all_twitter)
    else
        url.set(:count_all_twitter, url.counting_twitter)
    end
    url.set(:counting_twitter, 0)
end
