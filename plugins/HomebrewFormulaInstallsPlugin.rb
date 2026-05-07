require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches 30-day install counts for Homebrew formulae via the public
# formulae.brew.sh API. No auth required.
#
# Config:
#   plugins:
#     - HomebrewFormulaInstallsPlugin:
#         - wget
#         - ffmpeg
#
# Output (Liquid):
#   {{vars.HomebrewFormulaInstallsPlugin['wget']}} installs (30d)
class HomebrewFormulaInstallsPlugin < Plugin
    attr_reader :data, :formulae

    def initialize(data)
        @data = data

        formulae = {}
        data[0].each { |name| formulae[name] = 0 }
        @formulae = formulae
    end

    def execute
        formulae.each { |name, _| formulae[name] = load_installs(name) }
        return formulae
    end

    def load_installs(name)
        encoded = URI.encode_www_form_component(name.to_s)
        uri = URI("https://formulae.brew.sh/api/formula/#{encoded}.json")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        # analytics.install."30d".<formula-name> -> count
        bucket = body.dig("analytics", "install", "30d") || {}
        return bucket[name.to_s] || bucket.values.first || 0
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
