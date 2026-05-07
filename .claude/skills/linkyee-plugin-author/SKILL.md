---
name: linkyee-plugin-author
description: Use when the user wants to add a new plugin / dynamic variable to their linkyee site (e.g. "fetch my <some-stat>", "show my latest <something>", "add a counter for X"). Triggers on phrases like "add a plugin", "fetch X at build time", "expose X as {{ vars.X }}", "I want to display my <metric> from <service>". Generates a `plugins/<Name>.rb` file, registers it in `config.yml`, and verifies the build.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# linkyee Plugin Author

You help users add new plugins to **linkyee** so they can inject dynamic values (follower counts, latest posts, downloads, countdowns, etc.) into their page at build time. This skill encodes the plugin contract, idioms learned the hard way, and a copy-pasteable template so you don't have to re-derive them.

## How linkyee plugins work

- `scaffold.rb` (the build script) reads `config.yml`'s `plugins:` list. Each entry has the form `- <ClassName>: [<arg1>, <arg2>, ...]`.
- For each entry it `require_relative "./plugins/#{ClassName}.rb"`, instantiates `Object.const_get(ClassName).new(plugin.values)`, and stores the return of `execute()` under `settings["vars"][ClassName]`.
- Templates then reference the result as `{{ vars.<ClassName> }}` (scalar) or `{{ vars.<ClassName>['key'] }}` (hash).

**Key indirection:** `plugin.values` returns an array containing one element — the user's argument list. So `data[0]` inside `initialize(data)` is the user's array of args. Mirror this in every new plugin.

## Plugin contract — must hold for every new file

1. **Subclass `Plugin`** (defined in `plugins/Plugin.rb`).
2. **Filename matches class name** exactly. `MyAwesomePlugin` lives in `plugins/MyAwesomePlugin.rb`. `scaffold.rb` does `Object.const_get(pluginFileName)` so they have to match.
3. **`initialize(data)`** stores `data` and pre-populates the result structure with safe defaults (so an early failure still returns shape-correct output).
4. **`execute()`** does the work and returns the value to be exposed. Hash output is the most common — the existing `GithubRepoStarsCountPlugin` returns `{repo => stars}`; six in-tree plugins follow the same shape. Scalar return is fine for single-value plugins.
5. **Never raise.** Every external call must be wrapped in `rescue StandardError` and return a safe default. A crashing plugin breaks the user's whole site build.
6. **Side-effect free at require time.** Don't open sockets or read files at the top level — only inside `execute`.

## Available libraries (no new gems)

`Gemfile.lock` ships: `liquid`, `nokogiri`. Plus stdlib: `net/http`, `uri`, `json`, `date`, `time`. **Do not add new gems** — users deploy via GitHub Actions and `bundle install` runs on every build; new dependencies extend build time and risk Linux/macOS arch lockfile mismatches.

## Idioms and pitfalls

- **`Net::HTTP.get_response` does not follow redirects.** The original `GithubRepoStarsCountPlugin` uses it, which works for github.com but will silently break for hosts that 301. Prefer the `fetch(uri, limit)` helper pattern below, which uses `Net::HTTP.start` and recurses on `Net::HTTPRedirection`.
- **Always set `User-Agent`.** Several APIs (npm, dev.to, Mastodon instances) rate-limit or 403 the default Ruby UA.
- **Set timeouts** (`open_timeout`, `read_timeout` = 10s). Without them a hung host stalls the build indefinitely.
- **Guard Nokogiri lookups** with `&.text.to_s.strip` — `at_css(...)` returns `nil` on no match.
- **JSON parsing** must be inside the rescue. A 200 with malformed body is a real failure mode (e.g. captive-portal HTML at a Wi-Fi hotspot during a local build).
- **Keep one entry's failure isolated.** When iterating user-provided keys, wrap each iteration so one bad input doesn't zero out the others.

## Standard plugin template

```ruby
require_relative 'Plugin'
require 'net/http'
require 'uri'
require 'json'

# One-paragraph description of what this plugin does and what API it
# uses. Note auth requirements (or "no auth required").
#
# Config:
#   plugins:
#     - MyExamplePlugin:
#         - some-arg
#
# Output (Liquid):
#   {{vars.MyExamplePlugin['some-arg']}}
class MyExamplePlugin < Plugin
    attr_reader :data, :items

    def initialize(data)
        @data = data

        items = {}
        data[0].each { |key| items[key] = 0 }
        @items = items
    end

    def execute
        items.each { |key, _| items[key] = load_value(key) }
        return items
    end

    def load_value(key)
        encoded = URI.encode_www_form_component(key.to_s)
        uri = URI("https://api.example.com/v1/thing/#{encoded}")

        response = fetch(uri)
        return 0 unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        return body["count"] || 0
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
```

For HTML scraping, swap `require 'json'` for `require 'nokogiri'` and use `Nokogiri::HTML(response.body)` with `at_css`/`at_xpath`. For XML feeds, use `Nokogiri::XML` and call `.remove_namespaces!` before querying.

## Reference plugins to read first

When the request is close to one of these, read it before writing the new file:

| If the user wants… | Read |
|---|---|
| GitHub-style scraped count | `plugins/GithubRepoStarsCountPlugin.rb` (Nokogiri scrape) |
| JSON API hitting a public endpoint | `plugins/NpmPackageDownloadsPlugin.rb` |
| RSS/Atom feed parsing (generic) | `plugins/RssFeedLatestPostPlugin.rb` |
| RSS/Atom for a specific platform with an alias-map config | `plugins/YouTubeChannelLatestVideoPlugin.rb` |
| Public XRPC / REST follower count | `plugins/BlueskyFollowersCountPlugin.rb` |
| Per-instance API (handle parsing) | `plugins/MastodonFollowersCountPlugin.rb` |
| HTML scrape with regex fallback | `plugins/DevToFollowersCountPlugin.rb` |
| Multi-field hash output per key | `plugins/GitHubUserStatsPlugin.rb`, `plugins/AppStoreRatingPlugin.rb`, `plugins/LichessRatingPlugin.rb` |
| Nested-key JSON extraction (`dig`) | `plugins/PyPiPackageDownloadsPlugin.rb`, `plugins/CratesIoDownloadsPlugin.rb`, `plugins/PackagistDownloadsPlugin.rb` |
| API where `null` body means "user not found" | `plugins/HackerNewsKarmaPlugin.rb` |
| API returning gzipped responses (handled transparently by Net::HTTP) | `plugins/StackOverflowReputationPlugin.rb` |
| Strict User-Agent + path-with-slash encoding | `plugins/DockerHubPullsPlugin.rb`, `plugins/PackagistDownloadsPlugin.rb` |
| Username normalization (strip `@`, `u/`, etc.) | `plugins/RedditKarmaPlugin.rb` |
| Ruby gem registry parallel to npm | `plugins/RubyGemsDownloadsPlugin.rb` |
| GitLab-style URL-encoded project path | `plugins/GitlabRepoStarsCountPlugin.rb` |
| Date-range arithmetic + per-item summation | `plugins/WikipediaPageViewsPlugin.rb` |
| Lang/region prefix parsing (`zh:Article`) | `plugins/WikipediaPageViewsPlugin.rb` |
| Filtered count over a JSON array body | `plugins/OpenCollectiveBackersPlugin.rb` |
| Multi-key extraction from a deeply nested object | `plugins/HomebrewFormulaInstallsPlugin.rb` (`analytics.install.30d.<name>`) |
| Float-typed return value with rounding | `plugins/AppStoreRatingPlugin.rb` |
| Pure-logic / no network | `plugins/CountdownPlugin.rb` |

## Out-of-scope sources

Don't try to build plugins for these unless the user has told you they have credentials or are willing to commit a token to the repo:

- **OAuth required**: Spotify, Twitch, Strava, Steam, Patreon, Trakt, LinkedIn, GitHub GraphQL (sponsors/contributions counts), Google APIs
- **Login walls or aggressive anti-scraping**: Instagram, TikTok, Threads, Google Scholar
- **Deprecated public endpoints**: Last.fm RSS, Twitter/X public follower counts

If the user asks for one of the above, suggest the closest already-covered alternative (RSS feed for the platform, a different account stat, etc.) before agreeing to wire up secrets.

## Workflow you should follow

1. **Read context** — `Read` `plugins/Plugin.rb` (the base class is 12 lines, just confirm the contract) and the closest reference plugin from the table above.
2. **Confirm the brief.** If anything below is ambiguous, ask the user before coding:
   - Data source: URL, response format (JSON / HTML / XML), auth requirements.
   - Output shape: scalar vs hash; what keys/aliases the user will reference in templates.
   - Failure value: usually `0` for counts, `""` for strings, `{}` per-entry for structured output.
3. **Write `plugins/<ClassName>.rb`** from the template. Top-of-file comment must include: one-line description, config snippet, Liquid usage example.
4. **Register in `config.yml`** — append a block under `plugins:`. Use `Edit` and match the existing 2-space indentation. Don't touch any other section of `config.yml`.
5. **Verify the build** — `bundle exec ruby ./scaffold.rb`. Confirm:
   - Exit 0
   - `_output/index.html` exists
   - `grep -c '{{' _output/index.html` is `0` (no unrendered Liquid leaked)
6. **Tell the user how to use it** — show the exact `{{ vars.<ClassName>... }}` snippet to paste into a `links:` text field or `tagline`.

## Common pitfalls to avoid

- **Filename ≠ class name.** `scaffold.rb` does `Object.const_get(pluginFileName)`, so `plugins/my_plugin.rb` defining `MyPlugin` will fail. Use exact-match PascalCase.
- **Forgetting `data[0]`.** New authors often write `data.each` and get unexpected nesting. The wrapper is `data = [user_args]` because of how `plugin.values` flattens.
- **Letting one bad input crash the loop.** Per-iteration `begin/rescue` keeps a malformed user entry from zeroing out the rest.
- **Auth-required APIs.** If the data source needs an API key, the user has to commit it to the repo or wire a GitHub Actions secret. Prefer auth-free public endpoints. If auth is unavoidable, document the secret name in the plugin's top-of-file comment and read it from `ENV["..."]`.
- **Modifying `scaffold.rb`** to support a "fancy" plugin feature. Don't — the contract is intentionally simple, and any change ripples to every existing plugin.
- **Rate limits.** Some APIs (Mastodon per-instance, dev.to scraping) cap unauthenticated requests. Suggest the user keep the input array small.
