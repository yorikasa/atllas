# coding: utf-8

require 'openssl'
require 'base64'
require 'open-uri'
require 'cgi'
require 'nokogiri'

require './configure'

# Amazon Product Advertising API用のクラス
# 今のところは、requestメソッド専用
class Amazon
    def initialize
        @dest = "http://ecs.amazonaws.jp/onca/xml"
        @parameters = {
            Service: "AWSECommerceService",
            AWSAccessKeyId: ENV['AMAZON_ACCESS_KEY'],
            AssociateTag: ENV['AMAZON_ASSOCIATE_ID'],
            Operation: "ItemLookup",
            ResponseGroup: CGI.escape("Small,Images"),
            Version: "2011-08-01",
            Timestamp: CGI.escape(Time.now.gmtime.strftime("%FT%TZ"))
        }
    end

    # ASINを受け取って、それらしい情報のHashを返す
    # @param asin [String] ASINコード
    def request(asin)
        @parameters[:ItemId] = asin
        string_to_sign = ""
        parameter = ""

        string_to_sign << "GET\necs.amazonaws.jp\n/onca/xml\n"
        @parameters.sort_by{|k,v|k}.each do |k,v|
            parameter << "#{k}=#{v}&"
        end
        parameter = parameter[0..-2]
        string_to_sign << parameter
        hmac = OpenSSL::HMAC.digest("sha256", ENV['AMAZON_SECRET_ACCESS_KEY'], string_to_sign)
        signature = Base64.strict_encode64(hmac)
        signature = CGI.escape(signature)
        request = "#{@dest}?#{parameter}&Signature=#{signature}"

        doc = Nokogiri::XML(open(request))
        product = {
            detail_page_url: doc.css("DetailPageURL").first.text,
            image_url:       doc.css("LargeImage URL").first.text,
            title:           doc.css("ItemAttributes Title").first.text
        }
    end
end
