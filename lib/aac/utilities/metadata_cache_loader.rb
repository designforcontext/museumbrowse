require 'digest'
require 'fileutils'
require "babosa"
require "redis"
require "json"
require_relative "../../aac.rb"

module AAC
  module Utilities
    class MetadataCacheLoader
      class << self
        include MetadataHelper

        #-----------------------------------------------------------------------
        def load_cache(purge=true)
          redis = Redis.new 

          if purge
            AAC::INSTITUTION_PREFIXES.keys.each do |prefix|
              redis.del("aac:objects:#{prefix}")
              redis.del("aac:actors:#{prefix}")
            end
          end

          # Load all ManMadeObjects from disk
          Dir.glob("./metadata/ManMadeObject/**/*.jsonld").each_slice(1000) do |slice|
            redis.pipelined do            
              slice.each do |file|
                load_object(file, redis)
              end
            end
          end
          
          # Load all Actors from disk
          Dir.glob("./metadata/Actor/**/*.jsonld").each_slice(1000) do |slice|
             redis.pipelined do            
              slice.each do |file|
                load_actor(file, redis)
              end
            end
          end

          # Load all Types from disk
          Dir.glob("./metadata/Type/**/*.jsonld").each_slice(1000) do |slice|
             redis.pipelined do            
              slice.each do |file|
                load_type(file, redis)
              end
            end
          end
        end

        #-----------------------------------------------------------------------
        def load_type(file, redis)    
          id, uri, data, prefix = load_data_from_file(file, "type")
          return nil unless id

          redis.set("aac:uri:#{uri}",data)
         # redis.set("aac:data:#{id}", data)
          redis.set("aac:filename:#{id}",file)
          redis.set("aac:reverse_lookup:#{id}",uri)
          redis.rpush("aac:types:#{prefix}", id)
        end

        #-----------------------------------------------------------------------
        def load_object(file, redis)
          id, uri, data, prefix = load_data_from_file(file, "object")
          return nil unless id

          redis.set("aac:uri:#{uri}",data)
          redis.set("aac:filename:#{uri}",file)
         # redis.set("aac:data:#{id}", data)
          redis.set("aac:reverse_lookup:#{id}",uri)
          redis.rpush("aac:objects:#{prefix}", id)    
        end

        #-----------------------------------------------------------------------
        def load_actor(file, redis)
          id, uri, data, prefix, parsed_data = load_data_from_file(file, "actor")
          return nil unless id

          redis.set("aac:uri:#{uri}",data)
          redis.set("aac:filename:#{id}",file)
         # redis.set("aac:data:#{id}", data)

          # ULAN-ify the IDs
          redis.set("aac:reverse_lookup:no_redirect:#{id}",uri)
          begin
            if exact_match = parsed_data.dig("exact_match")
              unless exact_match.is_a? String
                exact_match = [exact_match].flatten(1).first["id"]
              end
              redis.set("aac:exact_match:#{id}",exact_match)
              match_prefix, match_id = exact_match.split(":")
              uri = "/actor/#{match_prefix}/#{match_id.to_slug.normalize.to_s}"
            end
          rescue Exception => e
            puts e
            puts parsed_data
          end
          redis.set("aac:reverse_lookup:#{id}",uri)
          redis.rpush("aac:actors:#{prefix}", id)
        end

    ################################################################################
    ################################################################################

        protected

       #-----------------------------------------------------------------------
       def load_data_from_file(file, object_type)
          if file.nil?
            # puts "missing filename when trying to load data from disk"
            return nil
          end
          contents = File.read(file)
          begin
            jsonld = JSON.parse(contents)
            data = jsonld["@graph"].first
            uri = generate_uri(data, object_type)
            prefix = lookup_organization(data)
            if data["id"].nil?
              puts "Problem loading data from #{file}: No ID."
              return nil
            elsif uri.nil?
              puts "Problem generating URI from #{file}."
              return nil
            elsif contents.nil?
              puts "Problem loading data from #{file}."
              return nil
            elsif prefix.nil?
              puts "could not determine prefixp for #{file}."
              return nil
            end
            return [data["id"], uri, contents, prefix, data]
          rescue => e
            puts "Could not parse #{file}: #{e}"
            puts e.backtrace
            return nil
          end

        end


        #-----------------------------------------------------------------------
        def generate_uri(data, object_type)

          prefix = lookup_organization(data)
          case object_type
          when "object", "actor"
            id =   first_or_only by_classification(data.dig("identified_by"),"aat:300404670")
            id ||= first_or_only by_classification(data.dig("identified_by"),"aat:300404621")
            id ||= first_or_only data.dig("identified_by","value")
          else
            nil
          end
          id ||= Digest::SHA256.hexdigest(data["id"].to_s)      

          uri = "/#{object_type}/#{prefix}/#{id.to_slug.normalize.to_s}"
        end

        
        #-----------------------------------------------------------------------
        def lookup_organization(data)
          data["id"].split(":").first
        end
      end 
    end
  end
end