require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches total Rust crate download counts via the public crates.io API.
# No auth required. crates.io enforces a User-Agent policy — the
# identifier in the User-Agent below identifies linkyee.
#
# Config:
#   plugins:
#     - CratesIoDownloadsPlugin:
#         - serde
#         - tokio
#
# Output (Liquid):
#   {{vars.CratesIoDownloadsPlugin['serde']}} total downloads
class CratesIoDownloadsPlugin < Plugin
    attr_reader :data, :crates

    def initialize(data)
        @data = data

        crates = {}
        data[0].each { |crate| crates[crate] = 0 }
        @crates = crates
    end

    def execute
        crates.each { |crate, _| crates[crate] = load_downloads(crate) }
        return crates
    end

    def load_downloads(crate)
        encoded = URI.encode_www_form_component(crate.to_s)
        uri = URI("https://crates.io/api/v1/crates/#{encoded}")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        return body.dig("crate", "downloads") || 0
    rescue StandardError
        return 0
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
