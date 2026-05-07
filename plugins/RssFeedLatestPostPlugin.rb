require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'nokogiri'

# Fetches the latest post from any RSS 2.0 or Atom feed.
#
# Config (entries can be either a string URL or a single-key alias mapping):
#   plugins:
#     - RssFeedLatestPostPlugin:
#         - tech_blog: "https://blog.zhgchg.li/feed"
#         - "https://medium.com/feed/ztravel"
#
# Output (Liquid):
#   {{vars.RssFeedLatestPostPlugin.tech_blog.title}}
#   <a href="{{vars.RssFeedLatestPostPlugin.tech_blog.link}}">latest post</a>
#
# On any failure (network, malformed XML, missing fields), the entry is
# returned as { "title" => "", "link" => "", "date" => "" } so templates
# render gracefully.
class RssFeedLatestPostPlugin < Plugin
    attr_reader :data, :feeds

    def initialize(data)
        @data = data

        feeds = {}
        data[0].each do |entry|
            if entry.is_a?(Hash)
                entry.each { |alias_name, url| feeds[alias_name.to_s] = url.to_s }
            else
                feeds[entry.to_s] = entry.to_s
            end
        end
        @feeds = feeds
    end

    def execute
        result = {}
        feeds.each do |alias_name, url|
            result[alias_name] = load_latest(url)
        end
        return result
    end

    def load_latest(url)
        empty = { "title" => "", "link" => "", "date" => "" }
        uri = URI(url)
        response = fetch(uri)
        return empty unless response.is_a?(Net::HTTPSuccess)

        doc = Nokogiri::XML(response.body)
        doc.remove_namespaces!

        if doc.at_xpath("//item")
            item = doc.at_xpath("//item")
            {
                "title" => item.at_xpath("./title")&.text.to_s.strip,
                "link"  => item.at_xpath("./link")&.text.to_s.strip,
                "date"  => item.at_xpath("./pubDate")&.text.to_s.strip
            }
        elsif doc.at_xpath("//entry")
            entry = doc.at_xpath("//entry")
            link_node = entry.xpath("./link").find { |l| l["rel"].nil? || l["rel"] == "alternate" } || entry.at_xpath("./link")
            {
                "title" => entry.at_xpath("./title")&.text.to_s.strip,
                "link"  => link_node ? (link_node["href"] || link_node.text).to_s.strip : "",
                "date"  => (entry.at_xpath("./published") || entry.at_xpath("./updated"))&.text.to_s.strip
            }
        else
            empty
        end
    rescue StandardError
        return { "title" => "", "link" => "", "date" => "" }
    end

    def fetch(uri, limit = 5)
        return nil if limit <= 0

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: 10, read_timeout: 10) do |http|
            request = Net::HTTP::Get.new(uri)
            request["User-Agent"] = "linkyee-plugin/1.0"
            request["Accept"] = "application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.8"
            response = http.request(request)
            case response
            when Net::HTTPRedirection
                return fetch(URI(response["location"]), limit - 1)
            else
                return response
            end
        end
    end
end
