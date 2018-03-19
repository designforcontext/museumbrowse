import 'lib/tasks/redis.rake'
require "yard"
require 'dotenv/tasks'


require 'sitemap_generator/tasks'
require 'fileutils'
require './lib/aac.rb'


# Generate code documentation 
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
YARD::Rake::YardocTask.new do |t|
 t.files         = ['lib/**/*.rb']  
 t.options       = ['--any', '--extra', '--opts'] 
 t.stats_options = ['--list-undoc']         
end


# Build and Deploy the site. 
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
namespace :deploy do
 
  #-------------------------------------
  task :js do 
    sh("yarn build")
  end

  #-------------------------------------
  task :upload do 
    sh("aws s3 cp ./build s3://browse.americanartcollaborative.org --recursive --acl public-read")
  end

  #-------------------------------------
  task :validate do
    require "sitemap-parser"
    sitemap = SitemapParser.new "http://localhost:5000/sitemap.xml", {recurse: true}
    sitemap.to_a.each do |uri|
      next unless uri.include? ".html"
      resp = Typhoeus.get("#{uri}?production=true", followlocation: true)
      if (code = resp.response_code) != 200
        puts "Problem: Code #{code}.\n#{uri}\n"      
      end
    end
  end

  #-------------------------------------
  task :build do
    require "sitemap-parser"
    require "typhoeus"

    FileUtils.rmtree 'build', secure: true
    FileUtils.mkdir_p("build")
    FileUtils.cp_r(Dir.glob("source/public/*"), "build")


    sitemap = SitemapParser.new "http://localhost:5000/sitemap.xml", {recurse: true}
    
    sitemap.to_a.each do |uri|
      puts uri
      next if uri.include?(".ttl")
      resp = Typhoeus.get("#{uri}?production=true", followlocation: true)

      path = uri.gsub("http://localhost:5000","").split("/")
      filename = path.empty? ? "index.html" : path.pop 
      path = "build/#{path.join("/")}"
      FileUtils.mkdir_p(path)
      File.open("#{path}/#{filename}", "w+") {|f| f.puts resp.body}        
    end
  end
end


# Fetch content from the triplestore 
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
namespace :sparql do

  #-------------------------------------
  desc "Download the index files of all the core entities"
  task :download_indexes do

    require 'sparql/client'
    include AAC::Metadata

    # Read in queries
    queries = {}
    Dir.glob("metadata/queries/global/*.sparql") do |query_file|  
      queries[File.basename(query_file,".sparql")] = File.read(query_file)
    end

    # Create the client
    sparql = SPARQL::Client.new("http://data.americanartcollaborative.org/sparql")
    
    # Ensure the directory exists
    FileUtils.mkdir_p("metadata/global_results") 

    # For each query, run it and  

    queries.each do |query_name, query|
      File.open("metadata/global_results/#{query_name}.json", "w+") do |file|
        puts "Running #{query_name}..."
        
        begin
          tries ||= 0
          data = sparql.query(query).collect do |result| 
            result.to_h
          end
        rescue JSON::ParserError => e
          puts "bad data retrieved from #{query_name}. #{e}"
        rescue Net::HTTP::Persistent::Error => e   
          sparql  = SPARQL::Client.new("http://data.americanartcollaborative.org/sparql")
          retry if (tries+=1) < 5
          puts "Too many resets running #{query}.  Bailing out."
          exit false
        end
        if data.count == 1
          data = data[0] 
        elsif data[0].count == 1
          new_data = {}
          data.each do |datum|
            new_data[datum.keys.first] ||= []
            new_data[datum.keys.first] << datum[datum.keys.first]
          end
          data = new_data
        end
        file.puts JSON.pretty_generate data  
      end
    end

    # Run some helper functions
    restructure_ulan_lookup!
  end

  task :download_heroes do
    include AAC::Utilities
    downloader = EntityDownloader.new
    File.foreach("metadata/featured_objects.csv","\n") do |object|
      file = downloader.download_entity(object,AAC::MAN_MADE_OBJECT)
      AAC::Utilities::MetadataCacheLoader.load_object(file, Redis.new)
    end
    JSON.parse(File.read("metadata/global_results/all_institutions.json"))["entity"].each do |actor|
      file = downloader.download_entity(actor,AAC::ACTOR)
      AAC::Utilities::MetadataCacheLoader.load_actor(file, Redis.new)
      
    end
  end

  #-------------------------------------
  desc "Download a small collection of entities"
  task :download_sample do 
    include AAC::Utilities
    downloader = EntityDownloader.new
    downloader.download(AAC::MAN_MADE_OBJECT.merge({number_of_records: 1000}))
    downloader.download(AAC::ACTOR.merge({number_of_records: 500}))
    
    # getty_downloader = EntityDownloader.new(sparql: "http://vocab.getty.edu/sparql.n3")
    # getty_downloader.download(AAC::ULAN_ACTOR.merge({number_of_records: 0}))
    # getty_downloader.download(AAC::AAT.merge({number_of_records: 0}))
  end

  #-------------------------------------
  desc "Download all the entities"
  task :download_all do 
    include AAC::Utilities
    downloader = EntityDownloader.new
    downloader.download(AAC::MAN_MADE_OBJECT.merge({number_of_records: 0}))
    downloader.download(AAC::ACTOR.merge({number_of_records: 0}))
  end

end


# Handle loading ElasticSearch and Redis
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
namespace :cache do
  
  #-------------------------------------
  desc "Remove all metadata records"
  task :purge do
    require 'redis'
    sleep(1)
    puts "Purging..."
    redis = Redis.new
    redis.flushdb  

    FileUtils.rmtree 'metadata/ManMadeObject/', secure: true
    FileUtils.rmtree 'metadata/Actor/', secure: true
    puts "...complete."
  end

  #-------------------------------------
  task :load_redis do
    AAC::Utilities::MetadataCacheLoader.load_cache
  end

  #-------------------------------------
  task :load_search do
    loader = AAC::Utilities::SearchLoader.new
    loader.load_search
  end

  task :load_remote_search => :dotenv do
    opts = {
      url: ENV["REMOTE_ELASTICSEARCH"]
    }
    loader = AAC::Utilities::SearchLoader.new(opts)
    loader.load_search
  end

  task :reenable_cache do
    Rake::Task['cache:update'].reenable
  end

  #-------------------------------------
  task :update => [:dotenv, :load_redis, :load_remote_search]
end


desc "Download a single person"
task :person, [:id] do |t, args|
  include AAC::Utilities
  file = EntityDownloader.new.download_entity(args[:id],AAC::ACTOR)
  AAC::Utilities::MetadataCacheLoader.load_actor(file, Redis.new)
end

desc "Download a ULAN person"
task :ulan, [:id] do |t, args|
  include AAC::Utilities
  downloader = EntityDownloader.new
  getty_downloader = EntityDownloader.new(sparql: "http://vocab.getty.edu/sparql.n3")
  lookup = JSON.parse(File.read("metadata/global_results/ulan_lookup.json"))
  download_ulan_related(args[:id], downloader, getty_downloader, lookup)
end

desc "Download all ULAN people"
task :all_ulan do
  include AAC::Utilities
  downloader = EntityDownloader.new
  getty_downloader = EntityDownloader.new(sparql: "http://vocab.getty.edu/sparql.n3")
  lookup = JSON.parse(File.read("metadata/global_results/ulan_lookup.json"))
  JSON.parse(File.read("metadata/global_results/all_ulan.json"))["entity"].each do |id|
    download_ulan_related(id, downloader, getty_downloader, lookup)
  end
end

def download_ulan_related(id, downloader, getty_downloader, lookup)
  redis = Redis.new
  paths = lookup[id].collect do |entity_id|
    downloader.download_entity(entity_id,AAC::ACTOR)
  end
  paths.each do |file|
    AAC::Utilities::MetadataCacheLoader.load_actor(file, redis)
  end
  file = getty_downloader.download_entity(id,AAC::ULAN_ACTOR)
  AAC::Utilities::MetadataCacheLoader.load_actor(file, redis)
  redis.quit
end 

desc "Download a single work"
task :work, [:id] do |t, args|
  include AAC::Utilities
  file = EntityDownloader.new.download_entity(args[:id],AAC::MAN_MADE_OBJECT)
  AAC::Utilities::MetadataCacheLoader.load_object(file, Redis.new)
end

task :validate => ["sitemap:clean", "sitemap:create", "deploy:validate"]

desc "Build Ye Olde Site"
task :deploy => ["sitemap:clean", "sitemap:create", "deploy:js", "deploy:build", "deploy:upload"]

desc "Download failed files"
task :redownload => ["cache:update", "sparql:download_sample", "cache:update"]

task :default => ["sparql:download_indexes", "cache:purge", "sparql:download_all", "all_ulan", "cache:update"]


