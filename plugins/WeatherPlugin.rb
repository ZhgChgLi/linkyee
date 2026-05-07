require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches current weather via wttr.in's public JSON API. No auth.
#
# Location can be a city name, airport code, country, lat,lon, or
# "~Eiffel+Tower"-style queries that wttr.in supports.
#
# Config (each entry is an alias mapping to a location string):
#   plugins:
#     - WeatherPlugin:
#         - taipei: "Taipei"
#         - sf: "San Francisco"
#
# Output (Liquid):
#   {{vars.WeatherPlugin.taipei.temp_c}}C / {{vars.WeatherPlugin.taipei.desc}}
class WeatherPlugin < Plugin
    attr_reader :data, :locations

    def initialize(data)
        @data = data

        locations = {}
        data[0].each do |entry|
            if entry.is_a?(Hash)
                entry.each { |alias_name, location| locations[alias_name.to_s] = location.to_s }
            else
                locations[entry.to_s] = entry.to_s
            end
        end
        @locations = locations
    end

    def execute
        result = {}
        locations.each do |alias_name, location|
            result[alias_name] = load_weather(location)
        end
        return result
    end

    def load_weather(location)
        empty = { "temp_c" => "", "temp_f" => "", "desc" => "", "humidity" => "" }
        encoded = URI.encode_www_form_component(location)
        uri = URI("https://wttr.in/#{encoded}?format=j1")

        response = fetch(uri)
        return empty unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        current = body.dig("current_condition", 0)
        return empty unless current

        {
            "temp_c"   => current["temp_C"].to_s,
            "temp_f"   => current["temp_F"].to_s,
            "desc"     => current.dig("weatherDesc", 0, "value").to_s,
            "humidity" => current["humidity"].to_s
        }
    rescue StandardError
        return { "temp_c" => "", "temp_f" => "", "desc" => "", "humidity" => "" }
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
