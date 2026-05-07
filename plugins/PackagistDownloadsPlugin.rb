require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches Packagist (Composer / PHP) package download counts via the
# public packages API. No auth required.
#
# Config (use vendor/package form):
#   plugins:
#     - PackagistDownloadsPlugin:
#         - laravel/framework
#         - symfony/console
#
# Output (Liquid):
#   {{vars.PackagistDownloadsPlugin['laravel/framework'].total}}
#   {{vars.PackagistDownloadsPlugin['laravel/framework'].monthly}}
#   {{vars.PackagistDownloadsPlugin['laravel/framework'].daily}}
class PackagistDownloadsPlugin < Plugin
    attr_reader :data, :packages

    def initialize(data)
        @data = data

        packages = {}
        data[0].each { |pkg| packages[pkg] = empty_record }
        @packages = packages
    end

    def execute
        packages.each { |pkg, _| packages[pkg] = load_record(pkg) }
        return packages
    end

    def empty_record
        { "total" => 0, "monthly" => 0, "daily" => 0 }
    end

    def load_record(pkg)
        # Per-segment encode to preserve the slash in vendor/package.
        encoded = pkg.to_s.split("/").map { |s| URI.encode_www_form_component(s) }.join("/")
        uri = URI("https://packagist.org/packages/#{encoded}.json")

        response = fetch(uri)
        return empty_record unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        downloads = body.dig("package", "downloads") || {}
        {
            "total"   => downloads["total"]   || 0,
            "monthly" => downloads["monthly"] || 0,
            "daily"   => downloads["daily"]   || 0
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
