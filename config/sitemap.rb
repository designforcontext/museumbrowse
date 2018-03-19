require "./lib/aac.rb"
require "redis"
require "redis"

# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "http://localhost:5000"
SitemapGenerator::Sitemap.public_path = 'source/public/'
SitemapGenerator::Sitemap.search_engines = nil

SitemapGenerator::Sitemap.create(compress: false) do
  redis = Redis.new 
  
  Dir.glob("./source/static_pages/*.md") do |file|  
    add "/#{File.basename(file, ".md")}.html"
  end

  JSON.parse(File.read("./metadata/global_results/all_institutions.json"))["entity"].each do |institution|
    uri = redis.get("aac:reverse_lookup:no_redirect:#{institution}")
    add "#{uri}.html"
  end

  AAC::INSTITUTION_PREFIXES.keys.each do |prefix|
    redis.lrange("aac:objects:#{prefix}",0,-1).collect do |obj|
      uri = redis.get("aac:reverse_lookup:#{obj}")
      add "#{uri}.html"
      add "#{uri}.json"
      add "#{uri}.ttl"

    end

    redis.lrange("aac:actors:#{prefix}",0,-1).collect do |obj|
      uri = redis.get("aac:reverse_lookup:#{obj}")
      add "#{uri}.html"
      add "#{uri}.json"
      add "#{uri}.ttl"
    end
  end
end
