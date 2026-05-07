require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches Reddit user total karma via the public /about.json endpoint.
# No auth required, but Reddit is strict about User-Agent and may 429
# on repeated requests from the same IP.
#
# Config (usernames without leading u/):
#   plugins:
#     - RedditKarmaPlugin:
#         - spez
#
# Output (Liquid):
#   {{vars.RedditKarmaPlugin['spez']}} karma
class RedditKarmaPlugin < Plugin
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
        username = user.to_s.sub(%r{\A(?:/u/|u/|@)}, "")
        encoded = URI.encode_www_form_component(username)
        uri = URI("https://www.reddit.com/user/#{encoded}/about.json")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        data_node = body["data"] || {}
        if data_node["total_karma"]
            return data_node["total_karma"]
        end
        return (data_node["link_karma"] || 0) + (data_node["comment_karma"] || 0)
    rescue StandardError
        return 0
    end

    def fetch(uri, limit = 3)
        return nil if limit <= 0

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: 10, read_timeout: 10) do |http|
            request = Net::HTTP::Get.new(uri)
            request["User-Agent"] = "linkyee-plugin/1.0 (+https://github.com/ZhgChgLi/linkyee)"
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
