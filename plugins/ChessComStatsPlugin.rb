require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches Chess.com ratings via the public published-data API. No auth.
# Chess.com requires a User-Agent that identifies the application.
#
# Config:
#   plugins:
#     - ChessComStatsPlugin:
#         - hikaru
#
# Output (Liquid):
#   {{vars.ChessComStatsPlugin['hikaru'].bullet}}
#   {{vars.ChessComStatsPlugin['hikaru'].blitz}}
#   {{vars.ChessComStatsPlugin['hikaru'].rapid}}
#   {{vars.ChessComStatsPlugin['hikaru'].daily}}
class ChessComStatsPlugin < Plugin
    attr_reader :data, :users

    def initialize(data)
        @data = data

        users = {}
        data[0].each { |user| users[user] = empty_stats }
        @users = users
    end

    def execute
        users.each { |user, _| users[user] = load_stats(user) }
        return users
    end

    def empty_stats
        { "bullet" => 0, "blitz" => 0, "rapid" => 0, "daily" => 0 }
    end

    def load_stats(user)
        encoded = URI.encode_www_form_component(user.to_s.downcase)
        uri = URI("https://api.chess.com/pub/player/#{encoded}/stats")

        response = fetch(uri)
        return empty_stats unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        {
            "bullet" => body.dig("chess_bullet", "last", "rating") || 0,
            "blitz"  => body.dig("chess_blitz",  "last", "rating") || 0,
            "rapid"  => body.dig("chess_rapid",  "last", "rating") || 0,
            "daily"  => body.dig("chess_daily",  "last", "rating") || 0
        }
    rescue StandardError
        return empty_stats
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
