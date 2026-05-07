require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches public GitHub user stats (followers, following, public repos)
# via api.github.com. No auth required, but unauthenticated requests are
# capped at 60/hour per IP.
#
# Config:
#   plugins:
#     - GitHubUserStatsPlugin:
#         - octocat
#
# Output (Liquid):
#   {{vars.GitHubUserStatsPlugin['octocat'].followers}}
#   {{vars.GitHubUserStatsPlugin['octocat'].public_repos}}
#   {{vars.GitHubUserStatsPlugin['octocat'].following}}
class GitHubUserStatsPlugin < Plugin
    attr_reader :data, :users

    def initialize(data)
        @data = data

        users = {}
        data[0].each do |user|
            users[user] = empty_stats
        end
        @users = users
    end

    def execute
        users.each do |user, _|
            users[user] = load_stats(user)
        end
        return users
    end

    def empty_stats
        { "followers" => 0, "following" => 0, "public_repos" => 0 }
    end

    def load_stats(user)
        encoded = URI.encode_www_form_component(user.to_s.sub(/\A@/, ""))
        uri = URI("https://api.github.com/users/#{encoded}")

        response = fetch(uri)
        return empty_stats unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        {
            "followers"    => body["followers"] || 0,
            "following"    => body["following"] || 0,
            "public_repos" => body["public_repos"] || 0
        }
    rescue StandardError
        return empty_stats
    end

    def fetch(uri, limit = 3)
        return nil if limit <= 0

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: 10, read_timeout: 10) do |http|
            request = Net::HTTP::Get.new(uri)
            request["User-Agent"] = "linkyee-plugin/1.0"
            request["Accept"] = "application/vnd.github+json"
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
