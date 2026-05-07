require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches App Store ratings via the public iTunes Lookup API.
# No auth required.
#
# Use the numeric App ID (the trailing digits in any App Store URL,
# e.g. apps.apple.com/app/id1452689527 -> 1452689527).
#
# Config:
#   plugins:
#     - AppStoreRatingPlugin:
#         - 1452689527
#
# Output (Liquid):
#   {{vars.AppStoreRatingPlugin[1452689527].rating}}
#   {{vars.AppStoreRatingPlugin[1452689527].count}} ratings
#   {{vars.AppStoreRatingPlugin[1452689527].name}}
class AppStoreRatingPlugin < Plugin
    attr_reader :data, :apps

    def initialize(data)
        @data = data

        apps = {}
        data[0].each { |id| apps[id] = empty_record }
        @apps = apps
    end

    def execute
        apps.each { |id, _| apps[id] = load_record(id) }
        return apps
    end

    def empty_record
        { "rating" => 0.0, "count" => 0, "name" => "" }
    end

    def load_record(id)
        encoded = URI.encode_www_form_component(id.to_s)
        uri = URI("https://itunes.apple.com/lookup?id=#{encoded}")

        response = fetch(uri)
        return empty_record unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        item = body["results"]&.first
        return empty_record unless item

        {
            "rating" => (item["averageUserRating"] || 0.0).to_f.round(2),
            "count"  => item["userRatingCount"] || 0,
            "name"   => item["trackName"].to_s
        }
    rescue StandardError
        return empty_record
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
