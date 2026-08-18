require 'cgi'
require 'date'
require 'fileutils'
require 'json'
require 'liquid'
require 'yaml'

CONFIG_PATH = "config.yml"
DESTINATION_DIR = "./_output"
SHARED_ASSETS_DIR = "./assets"
SENTINEL_FILE = "AUTO_GEN_FOLDER_DO_NOT_EDIT_FILE_HERE"
LOCALE_CODE_PATTERN = /\A[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*\z/

def load_yaml(path)
  YAML.load_file(path, permitted_classes: [Date, Time, Symbol]) || {}
end

def deep_merge(base, override)
  base.merge(override) do |_key, base_value, override_value|
    base_value.is_a?(Hash) && override_value.is_a?(Hash) ? deep_merge(base_value, override_value) : override_value
  end
end

def render_value(value, context)
  case value
  when String then Liquid::Template.parse(value).render(context)
  when Array then value.map { |item| render_value(item, context) }
  when Hash then value.transform_values { |item| render_value(item, context) }
  else value
  end
end

def plugin_values(settings)
  Array(settings["plugins"]).each_with_object({}) do |plugin, values|
    plugin_name = plugin.keys.first
    plugin_path = "./plugins/#{plugin_name}.rb"

    unless File.exist?(plugin_path)
      warn "[scaffold] Plugin not found: #{plugin_path} — skipping."
      values[plugin_name] = nil
      next
    end

    begin
      require_relative plugin_path
      values[plugin_name] = Object.const_get(plugin_name).new(plugin.values).execute
    rescue StandardError, LoadError => e
      warn "[scaffold] Plugin '#{plugin_name}' failed: #{e.class}: #{e.message}"
      warn e.backtrace.first(5).map { |line| "  #{line}" }.join("\n") if e.backtrace
      values[plugin_name] = nil
    end
  end
end

def add_build_values(settings, now)
  settings["last_modified_at"] = now.strftime("%Y-%m-%dT%H:%M:%S%z")
  settings["color_scheme"] ||= "auto"
  settings["year"] = now.year.to_s
  settings["month"] = now.strftime("%m")
  settings["day"] = now.strftime("%d")
  settings["today"] = now.strftime("%Y-%m-%d")
end

def prepare_context(base_settings, locale_settings, vars, now, locale:, i18n_enabled:, language_options:)
  context = deep_merge(base_settings, locale_settings)
  context["vars"] = vars
  context["locale"] = locale
  context["i18n_enabled"] = i18n_enabled
  context["language_options"] = language_options
  context["lang"] ||= locale
  add_build_values(context, now)

  %w[title avatar name tagline footer copyright links socials ui].each do |key|
    context[key] = render_value(context[key], context) if context.key?(key)
  end

  context
end

def copy_theme_assets(source_dir, destination_dir)
  FileUtils.cp_r("#{source_dir}/.", destination_dir)
  FileUtils.rm_f(File.join(destination_dir, "index.html"))
end

def copy_shared_assets(destination_dir, include_css: true)
  FileUtils.cp(File.join(SHARED_ASSETS_DIR, "i18n.js"), destination_dir)
  FileUtils.cp(File.join(SHARED_ASSETS_DIR, "i18n.css"), destination_dir) if include_css
end

def render_site(source_dir, destination_dir, context)
  source_template = File.join(source_dir, "index.html")
  raise "Error: #{source_template} file not found." unless File.exist?(source_template)

  FileUtils.mkdir_p(destination_dir)
  copy_theme_assets(source_dir, destination_dir)
  copy_shared_assets(destination_dir) if context["i18n_enabled"]
  rendered_content = Liquid::Template.parse(File.read(source_template, encoding: "UTF-8")).render(context)
  File.write(File.join(destination_dir, "index.html"), rendered_content)
end

def render_redirector(destination_dir, context)
  copy_shared_assets(destination_dir, include_css: false)
  default_option = context.fetch("language_options").find { |option| option["code"] == context["default_locale"] }
  locale_codes = CGI.escapeHTML(context.fetch("language_options").map { |option| option["code"] }.to_json)
  title = CGI.escapeHTML(context["title"].to_s)
  label = CGI.escapeHTML(default_option.fetch("label").to_s)
  redirector = <<~HTML
    <!DOCTYPE html>
    <html lang="#{CGI.escapeHTML(context["lang"].to_s)}" data-locale-root="true" data-default-locale="#{context["default_locale"]}" data-locales='#{locale_codes}'>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="robots" content="noindex">
      <title>#{title}</title>
      <script src="./i18n.js?v=#{context["last_modified_at"]}"></script>
    </head>
    <body>
      <noscript><a href="./#{context["default_locale"]}/">#{label}</a></noscript>
    </body>
    </html>
  HTML
  File.write(File.join(destination_dir, "index.html"), redirector)
end

def replace_entry(source, destination)
  FileUtils.rm_rf(destination)
  File.rename(source, destination)
end

def publish_staged_output(destination_dir, staging_dir)
  FileUtils.mkdir_p(destination_dir)
  sentinel = File.join(destination_dir, SENTINEL_FILE)
  File.write(sentinel, "") unless File.exist?(sentinel)

  entries = Dir.children(staging_dir)
  entries.reject { |entry| entry == "index.html" }.each do |entry|
    replace_entry(File.join(staging_dir, entry), File.join(destination_dir, entry))
  end

  stale_entries = Dir.children(destination_dir) - entries - [SENTINEL_FILE, File.basename(staging_dir)]
  stale_entries.each { |entry| FileUtils.rm_rf(File.join(destination_dir, entry)) }

  replace_entry(File.join(staging_dir, "index.html"), File.join(destination_dir, "index.html"))
  FileUtils.rm_rf(staging_dir)
end

def validate_locale_code!(locale)
  raise "Error: invalid locale code: #{locale.inspect}" unless LOCALE_CODE_PATTERN.match?(locale)
end

raise "Error: #{CONFIG_PATH} not found." unless File.exist?(CONFIG_PATH)

settings = load_yaml(CONFIG_PATH)
source_dir = "./themes/#{settings["theme"] || "default"}"
raise "Error: #{source_dir} directory not found." unless Dir.exist?(source_dir)

now = Time.now
vars = plugin_values(settings)
i18n = settings["i18n"]
staging_dir = File.join(DESTINATION_DIR, ".staging-#{Process.pid}")
FileUtils.rm_rf(staging_dir)
FileUtils.mkdir_p(staging_dir)

begin
  if i18n.is_a?(Hash) && i18n["locales"].is_a?(Hash) && !i18n["locales"].empty?
    raise "Error: #{SHARED_ASSETS_DIR} directory not found." unless Dir.exist?(SHARED_ASSETS_DIR)

    locale_files = i18n["locales"]
    default_locale = i18n["default_locale"].to_s
    locale_files.each_key { |locale| validate_locale_code!(locale) }
    raise "Error: i18n.default_locale must be one of i18n.locales." unless locale_files.key?(default_locale)

    locale_settings = locale_files.transform_values do |path|
      raise "Error: locale file not found: #{path}" unless File.exist?(path)

      load_yaml(path)
    end
    language_options = locale_settings.map do |code, locale_data|
      { "code" => code, "label" => locale_data["locale_label"] || code }
    end

    locale_settings.each do |locale, content|
      context = prepare_context(
        settings,
        content,
        vars,
        now,
        locale: locale,
        i18n_enabled: true,
        language_options: language_options
      )
      context["default_locale"] = default_locale
      render_site(source_dir, File.join(staging_dir, locale), context)
    end

    redirect_context = prepare_context(
      settings,
      locale_settings.fetch(default_locale),
      vars,
      now,
      locale: default_locale,
      i18n_enabled: true,
      language_options: language_options
    )
    redirect_context["default_locale"] = default_locale
    render_redirector(staging_dir, redirect_context)
  else
    context = prepare_context(
      settings,
      {},
      vars,
      now,
      locale: settings["lang"] || "en",
      i18n_enabled: false,
      language_options: []
    )
    render_site(source_dir, staging_dir, context)
  end

  publish_staged_output(DESTINATION_DIR, staging_dir)
rescue StandardError
  FileUtils.rm_rf(staging_dir)
  raise
end
