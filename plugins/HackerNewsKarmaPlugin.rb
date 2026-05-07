require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches Hacker News user karma via the public Firebase API. No auth.
#
# Config (HN usernames are case-sensitive):
#   plugins:
#     - HackerNewsKarmaPlugin:
#         - pg
#         - dang
#
# Output (Liquid):
#   {{vars.HackerNewsKarmaPlugin['pg']}} karma
class HackerNewsKarmaPlugin < Plugin
    attr_reader :data, :users

    def initialize(data)
        @data = data

        users = {}
        data[0].each { |user| users[user] = 0 }
        @users = users
    end

    def execute
        users.each { |user, _| users[user] = load_karma(user) }
        return users
    end

    def load_karma(user)
        encoded = URI.encode_www_form_component(user.to_s)
        uri = URI("https://hacker-news.firebaseio.com/v0/user/#{encoded}.json")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)
        return 0 if response.body.to_s.strip == "null"

        body = JSON.parse(response.body)
        return body["karma"] || 0
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
