require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches total pull counts for Docker Hub repositories via the public
# Hub v2 API. No auth required for public images.
#
# Config (use "user/image" form; for official library images use
# "library/<image>"):
#   plugins:
#     - DockerHubPullsPlugin:
#         - library/nginx
#         - grafana/grafana
#
# Output (Liquid):
#   {{vars.DockerHubPullsPlugin['library/nginx']}} pulls
class DockerHubPullsPlugin < Plugin
    attr_reader :data, :images

    def initialize(data)
        @data = data

        images = {}
        data[0].each { |image| images[image] = 0 }
        @images = images
    end

    def execute
        images.each { |image, _| images[image] = load_pulls(image) }
        return images
    end

    def load_pulls(image)
        path = image.to_s
        path = "library/#{path}" unless path.include?("/")
        # Per-segment encoding so the slash is preserved.
        encoded = path.split("/").map { |s| URI.encode_www_form_component(s) }.join("/")
        uri = URI("https://hub.docker.com/v2/repositories/#{encoded}")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        return body["pull_count"] || 0
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
