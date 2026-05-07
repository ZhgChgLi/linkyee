require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'nokogiri'

# Fetches the latest video from a YouTube channel via its public Atom feed
# (https://www.youtube.com/feeds/videos.xml?channel_id=<id>). No auth.
#
# Channel IDs look like "UC..." (24 chars). Find yours via View Page Source
# on your channel page and search for "channel_id".
#
# Config (each entry can be a bare channel ID or alias mapping):
#   plugins:
#     - YouTubeChannelLatestVideoPlugin:
#         - main: "UCXuqSBlHAE6Xw-yeJA0Tunw"
#         - "UC_x5XG1OV2P6uZZ5FSM9Ttw"
#
# Output (Liquid):
#   {{vars.YouTubeChannelLatestVideoPlugin.main.title}}
#   <a href="{{vars.YouTubeChannelLatestVideoPlugin.main.link}}">latest</a>
class YouTubeChannelLatestVideoPlugin < Plugin
    attr_reader :data, :channels

    def initialize(data)
        @data = data

        channels = {}
        data[0].each do |entry|
            if entry.is_a?(Hash)
                entry.each { |alias_name, channel_id| channels[alias_name.to_s] = channel_id.to_s }
            else
                channels[entry.to_s] = entry.to_s
            end
        end
        @channels = channels
    end

    def execute
        result = {}
        channels.each do |alias_name, channel_id|
            result[alias_name] = load_latest(channel_id)
        end
        return result
    end

    def load_latest(channel_id)
        empty = { "title" => "", "link" => "", "date" => "", "video_id" => "" }
        encoded = URI.encode_www_form_component(channel_id)
        uri = URI("https://www.youtube.com/feeds/videos.xml?channel_id=#{encoded}")

        response = fetch(uri)
        return empty unless response.is_a?(Net::HTTPSuccess)

        doc = Nokogiri::XML(response.body)
        doc.remove_namespaces!

        entry = doc.at_xpath("//entry")
        return empty unless entry

        link_node = entry.xpath("./link").find { |l| l["rel"].nil? || l["rel"] == "alternate" } || entry.at_xpath("./link")
        {
            "title"    => entry.at_xpath("./title")&.text.to_s.strip,
            "link"     => link_node ? (link_node["href"] || link_node.text).to_s.strip : "",
            "date"     => (entry.at_xpath("./published") || entry.at_xpath("./updated"))&.text.to_s.strip,
            "video_id" => entry.at_xpath("./videoId")&.text.to_s.strip
        }
    rescue StandardError
        return { "title" => "", "link" => "", "date" => "", "video_id" => "" }
    end

    def fetch(uri, limit = 5)
        return nil if limit <= 0

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: 10, read_timeout: 10) do |http|
            request = Net::HTTP::Get.new(uri)
            request["User-Agent"] = "linkyee-plugin/1.0"
            request["Accept"] = "application/atom+xml, application/xml;q=0.9"
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
