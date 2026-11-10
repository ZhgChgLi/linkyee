require 'fileutils'
require 'liquid'
require 'yaml'
require 'date'

unless File.exist?("config.yml")
    raise "Error: config.yml not found."
end

# Permit Date/Time so users can write unquoted YAML dates (e.g. for CountdownPlugin).
settings = YAML.load_file("config.yml", permitted_classes: [Date, Time, Symbol]) || {}

# Load localized theme UI strings. The default English labels keep other
# locales usable when a language-specific translation is missing.
settings["i18n"] = {
  "profile_picture" => "Profile Picture",
  "primary_links" => "Primary links",
  "latest" => "LATEST",
  "social_links" => "Social links"
}
locale_path = File.join("locales", "#{settings["lang"] || "en"}.yml")
if File.file?(locale_path)
  localized_labels = YAML.load_file(locale_path)
  settings["i18n"].merge!(localized_labels) if localized_labels.is_a?(Hash)
end

#
source_dir = "./themes/#{settings["theme"] || "default"}"
destination_dir = "./_output/"

# Clean _output folder. Keep index.html until the very end so concurrent
# HTTP readers (e.g. the local preview server) keep seeing the previous
# rendered build until the new one is atomically swapped in.
if Dir.exist?(destination_dir)
    Dir.foreach(destination_dir) do |file|
        next if file == '.' || file == '..' || file == 'AUTO_GEN_FOLDER_DO_NOT_EDIT_FILE_HERE'
        next if file == 'index.html'
        file_path = File.join(destination_dir, file)

        if File.file?(file_path)
            FileUtils.rm(file_path)
        end
    end
else
    FileUtils.mkdir_p(destination_dir)
end

# Copy all files and directories while preserving the structure.
# Skip index.html — we render it from the source and write atomically at the
# end so the served file is never raw Liquid mid-build (otherwise the local
# preview can serve unrendered templates while plugins are still fetching).
Dir.glob("#{source_dir}/**/*").each do |entry|
  relative_path = entry.sub("#{source_dir}/", '')
  next if relative_path == 'index.html'

  new_location = File.join(destination_dir, relative_path)

  if File.directory?(entry)
    FileUtils.mkdir_p(new_location)
  else
    FileUtils.cp(entry, new_location)
  end
end


source_template = "#{source_dir}/index.html"
template_file = "#{destination_dir}/index.html"
unless File.exist?(source_template)
    raise "Error: #{source_template} file not found."
end


template_content = File.read(source_template)

settings["vars"] = {}
if !settings["plugins"].nil?
  settings["plugins"].each do |plugin|
    pluginFileName = plugin.keys[0]
    plugin_path = "./plugins/#{pluginFileName}.rb"
    unless File.exist?(plugin_path)
      warn "[scaffold] Plugin not found: #{plugin_path} — skipping."
      settings["vars"][pluginFileName] = nil
      next
    end

    begin
      require_relative plugin_path
      pluginObject = Object.const_get(pluginFileName).new(plugin.values)
      settings["vars"][pluginFileName] = pluginObject.execute()
    rescue StandardError, LoadError => e
      warn "[scaffold] Plugin '#{pluginFileName}' failed: #{e.class}: #{e.message}"
      warn e.backtrace.first(5).map { |l| "  #{l}" }.join("\n") if e.backtrace
      settings["vars"][pluginFileName] = nil
    end
  end
end


if !settings["links"].nil?
  settings["links"].each_with_index do |link, index|
    settings["links"][index]["link"]["icon"] = Liquid::Template.parse(settings["links"][index]["link"]["icon"]).render(settings)
    settings["links"][index]["link"]["url"] = Liquid::Template.parse(settings["links"][index]["link"]["url"]).render(settings)
    settings["links"][index]["link"]["alt"] = Liquid::Template.parse(settings["links"][index]["link"]["alt"]).render(settings)
    settings["links"][index]["link"]["title"] = Liquid::Template.parse(settings["links"][index]["link"]["title"]).render(settings)
    settings["links"][index]["link"]["text"] = Liquid::Template.parse(settings["links"][index]["link"]["text"]).render(settings)
  end
end

if !settings["socials"].nil?
  settings["socials"].each_with_index do |link, index|
    settings["socials"][index]["social"]["icon"] = Liquid::Template.parse(settings["socials"][index]["social"]["icon"]).render(settings)
    settings["socials"][index]["social"]["url"] = Liquid::Template.parse(settings["socials"][index]["social"]["url"]).render(settings)
    settings["socials"][index]["social"]["alt"] = Liquid::Template.parse(settings["socials"][index]["social"]["alt"]).render(settings)
    settings["socials"][index]["social"]["title"] = Liquid::Template.parse(settings["socials"][index]["social"]["title"]).render(settings)
  end
end

# Date variables exposed to Liquid. Refreshed every build, so combine with
# the daily scheduled rebuild in .github/workflows/build.yml to keep
# year-based copy (e.g. copyright) up to date automatically. Set BEFORE the
# field-level Liquid renders below so {{ year }} works inside copyright,
# footer, tagline, etc.
now = Time.now
settings["last_modified_at"] = now.strftime("%Y-%m-%dT%H:%M:%S%z")
settings["color_scheme"] ||= "auto"   # auto | light | dark
settings["year"] = now.year.to_s
settings["month"] = now.strftime("%m")
settings["day"] = now.strftime("%d")
settings["today"] = now.strftime("%Y-%m-%d")

settings["title"] = Liquid::Template.parse(settings["title"]).render(settings)
settings["footer"] = Liquid::Template.parse(settings["footer"]).render(settings)
settings["tagline"] = Liquid::Template.parse(settings["tagline"]).render(settings)
settings["name"] = Liquid::Template.parse(settings["name"]).render(settings)
settings["copyright"] = Liquid::Template.parse(settings["copyright"].to_s).render(settings) if settings["copyright"]

# Parse the Liquid template
liquid_template = Liquid::Template.parse(template_content)

rendered_content = liquid_template.render(settings)

# Atomic write: produce the rendered output in a temp file on the same
# directory and rename into place. POSIX rename is atomic, so concurrent
# HTTP reads see either the previous build or the new one — never half-
# written content or raw Liquid.
tmp_file = "#{template_file}.tmp.#{Process.pid}"
File.open(tmp_file, 'w') { |f| f.write(rendered_content) }
File.rename(tmp_file, template_file)
