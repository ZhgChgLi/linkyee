require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches Mastodon follower counts via each instance's public
# /api/v1/accounts/lookup endpoint. No auth required (rate limited per
# instance).
#
# Config (full handles, e.g. @user@instance.social):
#   plugins:
#     - MastodonFollowersCountPlugin:
#         - "@Gargron@mastodon.social"
#
# Output (Liquid):
#   {{vars.MastodonFollowersCountPlugin['@Gargron@mastodon.social']}} followers
class MastodonFollowersCountPlugin < Plugin
    attr_reader :data, :handles

    def initialize(data)
        @data = data

        handles = {}
        data[0].each do |handle|
            handles[handle] = 0
        end
        @handles = handles
    end

    def execute
        handles.each do |handle, _|
            handles[handle] = load_followers(handle)
        end
        return handles
    end

    def load_followers(handle)
        match = handle.to_s.match(/\A@?([^@\s]+)@([^@\s]+)\z/)
        return 0 unless match

        user = match[1]
        host = match[2]
        encoded = URI.encode_www_form_component(user)
        uri = URI("https://#{host}/api/v1/accounts/lookup?acct=#{encoded}")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        return body["followers_count"] || 0
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
