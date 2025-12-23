require 'fileutils'
require 'liquid'
require 'yaml'

if File.exist?("config.yml")
    config = YAML.load_file("config.yml")
else
    raise "Error: config.yml not found."
end

settings = YAML.load_file("config.yml") || {}

#
source_dir = "./themes/#{settings["theme"] || "default"}"
destination_dir = "./_output/"

# Clean _output folder
if Dir.exist?(destination_dir)
    Dir.foreach(destination_dir) do |file|
        next if file == '.' || file == '..' || file == 'AUTO_GEN_FOLDER_DO_NOT_EDIT_FILE_HERE'
        file_path = File.join(destination_dir, file)

        if File.file?(file_path)
            FileUtils.rm(file_path)
        end
    end
else
    FileUtils.mkdir_p(destination_dir)
end

# Copy all files and directories while preserving the structure
Dir.glob("#{source_dir}/**/*").each do |entry|
  relative_path = entry.sub("#{source_dir}/", '')

  new_location = File.join(destination_dir, relative_path)

  if File.directory?(entry)
    FileUtils.mkdir_p(new_location)
  else
    FileUtils.cp(entry, new_location)
  end
end


template_file = "#{destination_dir}/index.html"
if !File.exist?(template_file)
    raise "Error: #{template_file} file not found."
end


template_content = File.read(template_file)

settings["vars"] = {}
if !settings["plugins"].nil?
  settings["plugins"].each do |plugin|
    pluginFileName = plugin.keys[0]
    if File.exist?("./plugins/#{pluginFileName}.rb")
      require_relative "./plugins/#{pluginFileName}.rb"
      pluginObject = Object.const_get(pluginFileName).new(plugin.values)
      settings["vars"][pluginFileName] = pluginObject.execute()
    end
  end
end


if !settings["links"].nil?
  # Check if links are categorized or flat
  if settings["links"].first && settings["links"].first["category"]
    # Categorized format: process categories
    settings["link_categories"] = []
    settings["links"].each do |category_item|
      category_name = category_item["category"]
      category_links = category_item["links"] || []
      
      # Process each link in the category
      processed_links = []
      category_links.each_with_index do |link, index|
        processed_link = link["link"].dup
        processed_link["icon"] = Liquid::Template.parse(processed_link["icon"]).render(settings)
        processed_link["url"] = Liquid::Template.parse(processed_link["url"]).render(settings)
        processed_link["alt"] = Liquid::Template.parse(processed_link["alt"]).render(settings)
        processed_link["title"] = Liquid::Template.parse(processed_link["title"]).render(settings)
        processed_link["text"] = Liquid::Template.parse(processed_link["text"]).render(settings)
        processed_links << {"link" => processed_link}
      end
      
      settings["link_categories"] << {
        "name" => category_name,
        "links" => processed_links
      }
    end
  else
    # Flat format: backward compatibility - convert to uncategorized
    settings["links"].each_with_index do |link, index|
      settings["links"][index]["link"]["icon"] = Liquid::Template.parse(settings["links"][index]["link"]["icon"]).render(settings)
      settings["links"][index]["link"]["url"] = Liquid::Template.parse(settings["links"][index]["link"]["url"]).render(settings)
      settings["links"][index]["link"]["alt"] = Liquid::Template.parse(settings["links"][index]["link"]["alt"]).render(settings)
      settings["links"][index]["link"]["title"] = Liquid::Template.parse(settings["links"][index]["link"]["title"]).render(settings)
      settings["links"][index]["link"]["text"] = Liquid::Template.parse(settings["links"][index]["link"]["text"]).render(settings)
    end
    # Convert flat links to categorized format for template consistency
    settings["link_categories"] = [{
      "name" => nil,
      "links" => settings["links"]
    }]
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

settings["title"] = Liquid::Template.parse(settings["title"]).render(settings)
settings["footer"] = Liquid::Template.parse(settings["footer"]).render(settings)
settings["tagline"] = Liquid::Template.parse(settings["tagline"]).render(settings)
settings["name"] = Liquid::Template.parse(settings["name"]).render(settings)
settings["last_modified_at"] = Time.now.strftime("%Y-%m-%dT%H:%M:%S%z")

# Parse the Liquid template
liquid_template = Liquid::Template.parse(template_content)

rendered_content = liquid_template.render(settings)

File.open(template_file, 'w') do |file|
  file.write(rendered_content)
end
