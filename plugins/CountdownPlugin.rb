require_relative 'Plugin'
require 'date'

# Computes days remaining until a target date. Pure Ruby — no network.
#
# Config (each entry is a single-key alias mapping to YYYY-MM-DD):
#   plugins:
#     - CountdownPlugin:
#         - book_launch: "2026-09-01"
#         - new_year: "2027-01-01"
#
# Output (Liquid):
#   {{vars.CountdownPlugin.book_launch}} days until launch
#
# Negative values mean the date has passed. Invalid date strings produce
# an empty string for that alias so the build doesn't fail.
class CountdownPlugin < Plugin
    attr_reader :data, :events

    def initialize(data)
        @data = data

        events = {}
        data[0].each do |entry|
            if entry.is_a?(Hash)
                entry.each { |alias_name, date_str| events[alias_name.to_s] = date_str.to_s }
            end
        end
        @events = events
    end

    def execute
        result = {}
        today = Date.today
        events.each do |alias_name, date_str|
            begin
                target = Date.parse(date_str)
                result[alias_name] = (target - today).to_i
            rescue ArgumentError, TypeError
                result[alias_name] = ""
            end
        end
        return result
    end
end
