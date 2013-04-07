#!/usr/bin/env ruby
# coding: utf-8

require 'open-uri'
require 'rss'
require 'mongoid'

require './configure'
Mongoid.load!('mongoid.yml')

class WhiteSite
    include Mongoid::Document
    field :domain, type: String
end

url = 'http://b.hatena.ne.jp/entrylist?sort=hot&threshold=10&mode=rss'
open(url) do |rss|
    feed = RSS::Parser.parse(rss)
    feed.items.each do |item|
        unless WhiteSite.where(domain: URI(item.link).host).exists?
            WhiteSite.create(domain: URI(item.link).host)
        end
    end
end
