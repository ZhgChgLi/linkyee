require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches total RubyGems download counts via the public rubygems.org API.
# No auth required.
#
# Config:
#   plugins:
#     - RubyGemsDownloadsPlugin:
#         - rails
#         - liquid
#
# Output (Liquid):
#   {{vars.RubyGemsDownloadsPlugin['rails']}} total downloads
class RubyGemsDownloadsPlugin < Plugin
    attr_reader :data, :gems

    def initialize(data)
        @data = data

        gems = {}
        data[0].each { |gem| gems[gem] = 0 }
        @gems = gems
    end

    def execute
        gems.each { |gem, _| gems[gem] = load_downloads(gem) }
        return gems
    end

    def load_downloads(gem)
        encoded = URI.encode_www_form_component(gem.to_s)
        uri = URI("https://rubygems.org/api/v1/gems/#{encoded}.json")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        return body["downloads"] || 0
    rescue StandardError
        return 0
    end

    def fetch(uri, limit = 3)
        return nil if limit <= 0

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: 10, read_timeout: 10) do |http|
            request = Net::HTTP::Get.new(uri)
            request["User-Agent"] = "linkyee-plugin/1.0"
            request["Accept"] = "application/json"
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
