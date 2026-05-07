require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches GitLab repo star and fork counts via the public projects API.
# No auth required for public projects.
#
# Use the full project path (group/subgroup/repo) — the plugin
# URL-encodes the slashes per GitLab's API convention.
#
# Config:
#   plugins:
#     - GitlabRepoStarsCountPlugin:
#         - gitlab-org/gitlab
#
# Output (Liquid):
#   {{vars.GitlabRepoStarsCountPlugin['gitlab-org/gitlab'].stars}} stars
#   {{vars.GitlabRepoStarsCountPlugin['gitlab-org/gitlab'].forks}} forks
class GitlabRepoStarsCountPlugin < Plugin
    attr_reader :data, :projects

    def initialize(data)
        @data = data

        projects = {}
        data[0].each { |path| projects[path] = empty_record }
        @projects = projects
    end

    def execute
        projects.each { |path, _| projects[path] = load_record(path) }
        return projects
    end

    def empty_record
        { "stars" => 0, "forks" => 0 }
    end

    def load_record(path)
        encoded = URI.encode_www_form_component(path.to_s)
        uri = URI("https://gitlab.com/api/v4/projects/#{encoded}")

        response = fetch(uri)
        return empty_record unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        {
            "stars" => body["star_count"]  || 0,
            "forks" => body["forks_count"] || 0
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
