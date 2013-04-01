# -*- coding: utf-8 -*-
require 'uri'
require 'open-uri'
require 'mechanize'
require 'timeout'
require 'readability'

class Webpage
    # @param url [String] WebページのURL
    def initialize(url)
        @url = deparam(popular_url?(fetch(url)))
    end

    attr_reader :url
    
    # 短縮URL (bit.ly等) などのリダイレクトをlimit回まで追いかける
    # うまくいけば最終的な行き先のURLを返す
    # @param url [String] WebページのURL
    # @param limit [Integer] リダイレクトを追いかける回数
    def fetch(url, limit=20)
        return url if limit < 0 or not url
        
        response = 0
        Timeout::timeout(5) do
            response = Net::HTTP.get_response(URI.parse(url))
        end
        case response
        when Net::HTTPRedirection
            fetch(response['location'], limit-1)
        when Net::HTTPSuccess
            return url
        when Net::HTTPBadGateway
            # 良くない処理かもしれないけど、httpsのときBad Gatewayになるので
            return url
        else
            nil
        end
    rescue => ex
        nil
    end

    def popular_url?(url)
        # For YouTube
        if /youtube\.com/ =~ URI(url).host
            if /v=(.+?)(&|\Z)/ =~ url
                url = "http://www.youtube.com/watch?v=#{$1}"
                return url
            end
        end
        # For Amazon
        if /amazon\.co\.jp/ =~ URI(url).host
            if /(dp|gp)\/(.+?)(\/|\Z)/ =~ url
                url = "http://www.amazon.co.jp/#{$1}/#{$2}"
                return url
            end
        end
        url
    rescue
        url
    end

    # URLから明らかに不要なパラメータを取り除く
    def deparam(url)
        return nil unless url
        url.gsub!(/[&?]*?utm_.+?=.+?(&|\Z)/, '')
        url.gsub!(/[&?]*?fr=.+?(&|\Z)/, '')
        url
    end

    # Webページのタイトルを取得して返す
    def title
        return nil unless @url
        return @title if @title
        page unless @page
        
        if @page.class == Mechanize::Page
            if @page.title
                @title = @page.title.gsub(/[\n\t\r\f]/, "").strip
                @title.gsub!(/\s+/, " ")
                return @title
            end
        else
            @url
        end
    rescue
        @url
    end

    # ReadabilityでWebページの本文 (と判断されたもの) を返す
    # @return [String] 本文らしきもの
    def body
        return nil unless @url
        return @body if @body
        page unless @page
        
        @body =  Readability::Document.new(@page.body).content.encode('utf-8')
        @body.gsub!(/(<\/?div>|<\/?p>)/,'')
        @body.gsub!(/https?:.+?(\s|\Z)/, '')
        if @body.size > @page.title.size
            return @body
        else
            return @page.title
        end
    rescue
        if @page.class == Mechanize::Page
            return @page.title
        else
            return ""
        end
    end

    # Mechanizeでpageオブジェクトを取得。
    # インスタンス変数に保存する。
    def page
        return @page if @page
        
        agent = Mechanize.new
        agent.user_agent = 'squid'
        agent.max_history = 1
        agent.open_timeout   = 3
        agent.read_timeout   = 3
        # http://stackoverflow.com/questions/13186289/getaddrinfo-error-with-mechanize
        # # getaddrinfo error with Mechanize
        # > Mechanize was leaving the connection open and relying on GC to
        # > clean them up. After a certain point, there were enough open connections
        # > that no additional outbound connection could be established to do a DNS
        # > lookup. Here's the code that caused it to work:
        # > By setting keep_alive to false, the connection is immediately closed
        # > and cleaned up.
        agent.keep_alive = false

        # おまじないみたいな
        agent.content_encoding_hooks << lambda{|httpagent,uri,response,body_io|
            valid = /compress|deflate|exi|gzip|identity|pack200-gzip/
            unless valid =~ response['content-encoding']
                response.delete('content-encoding')
            end
        }
        @page = agent.get(url)
    end
end

