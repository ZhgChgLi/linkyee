require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches Bluesky follower counts via the public XRPC endpoint
# (app.bsky.actor.getProfile). No auth required.
#
# Config (handles, with or without leading @):
#   plugins:
#     - BlueskyFollowersCountPlugin:
#         - zhgchgli.bsky.social
#
# Output (Liquid):
#   {{vars.BlueskyFollowersCountPlugin['zhgchgli.bsky.social']}} followers
class BlueskyFollowersCountPlugin < Plugin
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
        actor = handle.to_s.sub(/\A@/, "")
        encoded = URI.encode_www_form_component(actor)
        uri = URI("https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=#{encoded}")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        return body["followersCount"] || 0
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
