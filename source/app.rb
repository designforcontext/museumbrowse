# Ruby Standard Library
require "json"
require "yaml"
require "benchmark"

# Sinatra & Extensions
require 'sinatra/base'
require "sinatra/reloader" 
require "sinatra/json"
require "sinatra/content_for"
require "sinatra/link_header"

# Linked Data Libraries
require "linkeddata"

# Views and Templates
require "haml"
require "sass"
require "commonmarker"
require "front_matter_parser"
require 'active_support'
require "active_support/inflector"
require 'active_support/core_ext'
require "active_support/core_ext/numeric"


# Application Libraries and Helpers
 require './lib/aac.rb'

#-------------------------------------------------------------------------------
class AmericanArtCollaborativeSite < Sinatra::Base

  # Load helpers
  helpers Sinatra::LinkHeader
  helpers Sinatra::ContentFor
  helpers MetadataHelper, LinkHelper, IconHelper, EntityHelper, ImageHelper, ToyboxHelper

  #  Development-Environment-specific configuration
  configure :development do
    register Sinatra::Reloader
    Dir.glob('./lib/**/*.rb') { |file| also_reload file}
    set :show_exceptions, :after_handler
  end

  # Global configuration
  configure do 
    set :redis, Redis.new  
    set :haml, layout: 'layouts/layout'.to_sym
    set :views, "source"
  end
 

#------------------------------------------------------------------------------#
#                            ROUTES BELOW                                      #
#------------------------------------------------------------------------------#
before do
  if settings.environment == :production || request.params.keys.include?("production")
    @jspath = "/"
  else
    @jspath = "//localhost:7000/dist/"
  end
end

# INDEX ROUTE
#-------------------------------------------------------------------------------
  get "/" do
    redirect "/index.html"
  end


# STATIC PAGES (Housekeeping) 
# 
# These are generated dynamically from markdown files 
# found in the source/static_pages directory.

# Index
#-------------------------------------------------------------------------------
  get "/index.html" do

    data = {}
    homepage_global_queries = %w{mmo_count actor_count institution_count artist_count}
    homepage_global_queries.each do |thing|
      data = data.merge(JSON.parse(File.read("metadata/global_results/#{thing}.json")))
    end

    institution_ids = JSON.parse(File.read("metadata/global_results/all_institutions.json"))["entity"]
    data["institutions"] = institution_ids
      .map do |id| 
        # hack for wonky aaa
        next if id == "http://data.americanartcollaborative.org/aaa"
        id = "ycba:person-institution/ycba" if id.include? "yale"
        begin
          uri = settings.redis.get("aac:reverse_lookup:no_redirect:#{id}")
          puts "url;: #{uri}"
          JSON.parse(settings.redis.get("aac:uri:#{uri}"))["@graph"][0]
        rescue => e
          puts "Error: #{id} cannot be retrieved"
          next 
        end
      end.compact.sort_by{|datum| datum["label"].gsub(/^The /,"")  }
    
    parsed = FrontMatterParser::Parser.parse_file("source/static_pages/index.md")
    text = CommonMarker.render_html(parsed.content, :HARDBREAKS)
    
    haml :"templates/index.html", :locals => { :text => text, :data => data.merge(parsed.front_matter)}
  end

# Markdown-based pages
#-------------------------------------------------------------------------------
  Dir.glob("source/static_pages/*.md") do |file|  
    page = File.basename(file).gsub(/\.md$/, "")
    regex = /\/#{Regexp.quote(page)}.html/
    get regex do
      parsed = FrontMatterParser::Parser.parse_file(file)
      text = CommonMarker.render_html(parsed.content, :HARDBREAKS)
      haml :"templates/static.html", :locals => { :text => text, :data => parsed.front_matter}
    end    
  end


# ENTITY PAGES
#
# This is the fallback route, and will scan the Redis cache for an ID associated
# with the url.  It's used to generate json/ttl/html pages for each entity.
#-------------------------------------------------------------------------------
  get "/*id(.:extension)?" do |id,extension|

  # get /(.+?)(?:|.(.*))?/  do |id,extension|  # match either url, url/, or url.ext
    # id  = params[:captures].first
    # extension =  params[:captures].last
    puts id
    file = settings.redis.get("aac:uri:/#{id}")
    halt 404 unless file

    
    case extension
    when "json", "jsonld"
      content_type "application/json"
      file
    when "ttl"
      puts settings.redis.get("aac:filename:/#{id}")
      filename = settings.redis.get("aac:filename:/#{id}").gsub(".jsonld",".ttl")
      content_type "text/turtle"
      File.read(filename) 
      # input = JSON.parse file

      # graph = RDF::Graph.new << JSON::LD::API.toRdf(input)

      # prefixes = AAC::INSTITUTION_PREFIXES
      # prefixes.merge!( {
      #   "crm": "http://www.cidoc-crm.org/cidoc-crm/", 
      #   "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#", 
      #   "rdfs": "http://www.w3.org/2000/01/rdf-schema#", 
      #   "dc": "http://purl.org/dc/elements/1.1/", 
      #   "dcterms": "http://purl.org/dc/terms/", 
      #   "schema": "http://schema.org/", 
      #   "skos": "http://www.w3.org/2004/02/skos/core#", 
      #   "foaf": "http://xmlns.com/foaf/0.1/", 
      #   "pi": "http://linked.art/ns/prov/", 
      #   "aat": "http://vocab.getty.edu/aat/", 
      #   "ulan": "http://vocab.getty.edu/ulan/", 
      #   "tgn": "http://vocab.getty.edu/tgn/"  
      # })
      # graph.dump(:ttl, prefixes: prefixes)

    when "html", nil
      raw_data = JSON.parse(file)
      data = raw_data["@graph"].first
      @context = raw_data["@context"]
      case data["type"]
      when "Actor", ["LegalBody", "Actor"], ["Actor", "LegalBody"], ["Person", "Actor"], ["Actor", "Person"]
        haml :"templates/actor.html", locals: {obj: data}
      when "ManMadeObject"
        haml :"templates/object.html", locals: {obj: data}
      else
        "Haven't written a parser for #{data["type"]} yet. #{data}"
      end
    else
      params[:captures].inspect
    end
  end
end
