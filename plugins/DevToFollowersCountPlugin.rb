require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'nokogiri'

# Fetches dev.to follower counts.
#
# NOTE: The public dev.to API (/api/users/by_username) does not expose
# follower counts, so this plugin scrapes the public profile page at
# https://dev.to/<username>. Markup changes on dev.to may break it; the
# plugin falls back to a regex over the raw HTML before giving up.
#
# Config:
#   plugins:
#     - DevToFollowersCountPlugin:
#         - benhalpern
#         - ben
#
# Output (Liquid):
#   {{vars.DevToFollowersCountPlugin['benhalpern']}} followers
class DevToFollowersCountPlugin < Plugin
    attr_reader :data, :users

    def initialize(data)
        @data = data

        users = {}
        data[0].each do |user|
            users[user] = 0
        end
        @users = users
    end

    def execute
        users.each do |user, _|
            users[user] = load_followers(user)
        end
        return users
    end

    def load_followers(user)
        username = user.to_s.sub(/\A@/, "")
        encoded = URI.encode_www_form_component(username)
        uri = URI("https://dev.to/#{encoded}")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = response.body.to_s

        document = Nokogiri::HTML(body)
        node = document.at_css("[data-followers-count]")
        if node && node["data-followers-count"]
            value = node["data-followers-count"].to_s
            return value.to_i if value =~ /\A\d+\z/
        end

        match = body.match(/([\d,]+)\s+follower(?:s)?\b/i)
        return 0 unless match

        return match[1].delete(",").to_i
    rescue StandardError
        return 0
    end

    def fetch(uri, limit = 3)
        return nil if limit <= 0

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: 10, read_timeout: 10) do |http|
            request = Net::HTTP::Get.new(uri)
            request["User-Agent"] = "linkyee-plugin/1.0"
            request["Accept"] = "text/html,application/xhtml+xml"
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
