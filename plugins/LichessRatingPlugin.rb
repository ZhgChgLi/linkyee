require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches Lichess ratings via the public /api/user endpoint. No auth.
# Returns rating across the major time controls.
#
# Config:
#   plugins:
#     - LichessRatingPlugin:
#         - DrNykterstein
#
# Output (Liquid):
#   {{vars.LichessRatingPlugin['DrNykterstein'].blitz}}
#   {{vars.LichessRatingPlugin['DrNykterstein'].rapid}}
#   {{vars.LichessRatingPlugin['DrNykterstein'].classical}}
#   {{vars.LichessRatingPlugin['DrNykterstein'].bullet}}
class LichessRatingPlugin < Plugin
    attr_reader :data, :users

    def initialize(data)
        @data = data

        users = {}
        data[0].each { |user| users[user] = empty_perfs }
        @users = users
    end

    def execute
        users.each { |user, _| users[user] = load_perfs(user) }
        return users
    end

    def empty_perfs
        { "bullet" => 0, "blitz" => 0, "rapid" => 0, "classical" => 0 }
    end

    def load_perfs(user)
        encoded = URI.encode_www_form_component(user.to_s)
        uri = URI("https://lichess.org/api/user/#{encoded}")

        response = fetch(uri)
        return empty_perfs unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        perfs = body["perfs"] || {}
        {
            "bullet"    => perfs.dig("bullet",    "rating") || 0,
            "blitz"     => perfs.dig("blitz",     "rating") || 0,
            "rapid"     => perfs.dig("rapid",     "rating") || 0,
            "classical" => perfs.dig("classical", "rating") || 0
        }
    rescue StandardError
        return empty_perfs
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
