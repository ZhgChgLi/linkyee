require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches recent PyPI download counts via the public pypistats.org API.
# No auth required.
#
# Config:
#   plugins:
#     - PyPiPackageDownloadsPlugin:
#         - requests
#         - django
#
# Output (Liquid):
#   {{vars.PyPiPackageDownloadsPlugin['requests']}} downloads last week
class PyPiPackageDownloadsPlugin < Plugin
    attr_reader :data, :packages

    def initialize(data)
        @data = data

        packages = {}
        data[0].each { |pkg| packages[pkg] = 0 }
        @packages = packages
    end

    def execute
        packages.each { |pkg, _| packages[pkg] = load_downloads(pkg) }
        return packages
    end

    def load_downloads(pkg)
        encoded = URI.encode_www_form_component(pkg.to_s)
        uri = URI("https://pypistats.org/api/packages/#{encoded}/recent")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        return body.dig("data", "last_week") || 0
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
