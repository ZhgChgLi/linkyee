require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches Stack Overflow reputation via the public Stack Exchange API.
# No auth required (300 requests/day per IP without an API key).
#
# StackOverflow user IDs are numeric. Find yours in the URL of your
# profile: https://stackoverflow.com/users/<ID>/<name>
#
# Config:
#   plugins:
#     - StackOverflowReputationPlugin:
#         - 22656
#
# Output (Liquid):
#   {{vars.StackOverflowReputationPlugin[22656]}} reputation
#
# Note: Stack Exchange responses are gzip-encoded; Ruby's Net::HTTP
# transparently decompresses when no explicit Accept-Encoding is set.
class StackOverflowReputationPlugin < Plugin
    attr_reader :data, :users

    def initialize(data)
        @data = data

        users = {}
        data[0].each { |id| users[id] = 0 }
        @users = users
    end

    def execute
        users.each { |id, _| users[id] = load_reputation(id) }
        return users
    end

    def load_reputation(id)
        encoded = URI.encode_www_form_component(id.to_s)
        uri = URI("https://api.stackexchange.com/2.3/users/#{encoded}?site=stackoverflow")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        item = body["items"]&.first
        return item ? (item["reputation"] || 0) : 0
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
