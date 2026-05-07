require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# Fetches Open Collective backer/sponsor counts via the public
# /<slug>/members.json endpoint. No auth required.
#
# Config (use the collective slug from its URL: opencollective.com/<slug>):
#   plugins:
#     - OpenCollectiveBackersPlugin:
#         - babel
#         - webpack
#
# Output (Liquid):
#   {{vars.OpenCollectiveBackersPlugin['babel'].backers}} backers
#   {{vars.OpenCollectiveBackersPlugin['babel'].total}} total members
class OpenCollectiveBackersPlugin < Plugin
    attr_reader :data, :collectives

    def initialize(data)
        @data = data

        collectives = {}
        data[0].each { |slug| collectives[slug] = empty_record }
        @collectives = collectives
    end

    def execute
        collectives.each { |slug, _| collectives[slug] = load_record(slug) }
        return collectives
    end

    def empty_record
        { "backers" => 0, "total" => 0 }
    end

    def load_record(slug)
        encoded = URI.encode_www_form_component(slug.to_s)
        uri = URI("https://opencollective.com/#{encoded}/members.json")

        response = fetch(uri)
        return empty_record unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        return empty_record unless body.is_a?(Array)

        backer_roles = ["BACKER", "SPONSOR", "FUNDRAISER"]
        backers = body.count { |m| backer_roles.include?(m["role"].to_s) }
        {
            "backers" => backers,
            "total"   => body.size
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
