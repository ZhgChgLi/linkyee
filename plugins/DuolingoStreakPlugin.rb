require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches public Duolingo profile stats (streak, total XP) via the
# unauthenticated /2017-06-30/users endpoint. The user's profile must
# be public for the endpoint to return data.
#
# Note: this is an undocumented public endpoint and may change without
# notice. Failures fall back to zero values.
#
# Config:
#   plugins:
#     - DuolingoStreakPlugin:
#         - your-username
#
# Output (Liquid):
#   {{vars.DuolingoStreakPlugin['your-username'].streak}} day streak
#   {{vars.DuolingoStreakPlugin['your-username'].total_xp}} XP
class DuolingoStreakPlugin < Plugin
    attr_reader :data, :users

    def initialize(data)
        @data = data

        users = {}
        data[0].each { |user| users[user] = empty_record }
        @users = users
    end

    def execute
        users.each { |user, _| users[user] = load_record(user) }
        return users
    end

    def empty_record
        { "streak" => 0, "total_xp" => 0 }
    end

    def load_record(user)
        encoded = URI.encode_www_form_component(user.to_s)
        uri = URI("https://www.duolingo.com/2017-06-30/users?username=#{encoded}&fields=streak,totalXp")

        response = fetch(uri)
        return empty_record unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        first = (body["users"] || []).first
        return empty_record unless first

        {
            "streak"   => first["streak"]  || 0,
            "total_xp" => first["totalXp"] || 0
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
