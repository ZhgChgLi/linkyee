require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'
require 'date'

# Fetches the last 30 days of page views for a Wikipedia article via
# the Wikimedia REST API. No auth required.
#
# Config (each entry is an alias mapping to "<lang>:<Article_Title>";
# if no colon, defaults to en):
#   plugins:
#     - WikipediaPageViewsPlugin:
#         - einstein: "Albert_Einstein"
#         - taipei: "zh:%E5%8F%B0%E5%8C%97%E5%B8%82"
#
# Output (Liquid):
#   {{vars.WikipediaPageViewsPlugin.einstein}} views (last 30 days)
class WikipediaPageViewsPlugin < Plugin
    attr_reader :data, :articles

    def initialize(data)
        @data = data

        articles = {}
        data[0].each do |entry|
            if entry.is_a?(Hash)
                entry.each { |alias_name, article| articles[alias_name.to_s] = article.to_s }
            else
                articles[entry.to_s] = entry.to_s
            end
        end
        @articles = articles
    end

    def execute
        result = {}
        # Wikimedia pageview data lags by ~1 day; query [today-31, today-1]
        end_date   = Date.today - 1
        start_date = end_date - 29

        articles.each do |alias_name, article_spec|
            result[alias_name] = load_views(article_spec, start_date, end_date)
        end
        return result
    end

    def load_views(article_spec, start_date, end_date)
        lang, article = parse_spec(article_spec)
        # Article title may already be percent-encoded — only encode if it looks raw.
        encoded_article = article.include?("%") ? article : URI.encode_www_form_component(article)
        # Wikimedia uses underscores instead of spaces; encode_www_form_component
        # turns spaces into '+' so normalise that back to '_'.
        encoded_article = encoded_article.gsub("+", "_")

        start_str = start_date.strftime("%Y%m%d")
        end_str   = end_date.strftime("%Y%m%d")
        project = "#{lang}.wikipedia"

        uri = URI("https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/#{project}/all-access/all-agents/#{encoded_article}/daily/#{start_str}/#{end_str}")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        items = body["items"] || []
        return items.sum { |item| (item["views"] || 0).to_i }
    rescue StandardError
        return 0
    end

    def parse_spec(spec)
        if spec.include?(":")
            lang, _, article = spec.partition(":")
            return [lang.strip, article]
        end
        return ["en", spec]
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
