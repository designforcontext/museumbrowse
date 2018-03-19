require 'elasticsearch'
require 'redis'
require 'json'
require_relative "../../aac.rb"

module AAC
  module Utilities
    class SearchLoader
      include EntityHelper
      include MetadataHelper
      include ImageHelper
      include LinkHelper

      def initialize(user_opts ={})
        defaults = {
          log: false,
          retry_on_failure: true,
          trace: false,
          request_timeout: 5*60,
          index_name: "aac-search"
        }
        opts = defaults.merge!(user_opts)
        @index = opts[:index_name]
        @client = Elasticsearch::Client.new(opts) 
        @redis = Redis.new
      end

      def load_search(user_opts = {})

        party_ids = []
        record_ids = []
        event_ids = []

        defaults = {
          purge_db: true,
          index_settings: {
            mappings: {
              "_default_": {
                properties: {
                  label: {
                    "type": "text",
                    "analyzer": "english"
                  },
                  description: {
                    "type": "text",
                    "analyzer": "english"
                  },
                  id: {
                    "type": "keyword"
                  }
                }
              }
            }
          }
        }
        opts = defaults.merge(user_opts)

        ## (Re)create DB
        if @client.indices.exists(index: @index) && opts[:purge_db]
          @client.indices.delete index: @index 
        end

        unless @client.indices.exists(index: @index)
          @client.indices.create index: @index, body: opts[:index_settings]
        end

         @seen_ids = []
        AAC::INSTITUTION_PREFIXES.keys.each do |prefix|
          load_ids("aac:objects:#{prefix}", "objects") do |obj|

            produced_by = [obj["produced_by"]].flatten(1).collect do |p|
              if p && p["carried_out_by"]
               p["carried_out_by"] = [p["carried_out_by"]].flatten(1).collect do |q|                 
                  q["id"] = lookup_exact_match(q["id"])
                  q
                end
              end
              p
            end

            data = {
              label: get_object_title(obj),
              current_owner: {
                label: display_value(obj["current_owner"], field: "label"),
                id: lookup_exact_match(obj.dig("current_owner","id")),
              },
              medium: by_classification(obj["referred_to_by"],"aat:300264237"),
              type: obj["type"],
              subject_of: obj["subject_of"],
              produced_by: produced_by
            }
            img = get_object_image(obj, @redis)
            data[:representation] = {id: img} if img

            if obj["classified_by"] 
              data[:classified_by] = obj["classified_by"]
            end


            data
          end
          
          load_ids("aac:actors:#{prefix}",  "actors") do |obj|
            data = {
              label: get_actor_name(obj),
              description: get_actor_bio(obj),
              type: obj["type"],
              created_count: (obj["toybox:created_by"].count rescue 0)
            }
            img = get_actor_image(obj, @redis)
            data[:representation] = {id: img} if img
            data
          end
        end

      end

      protected

      #-------

      def lookup_exact_match(id)
        result = @redis.get("aac:exact_match:#{id}") 
        result || id
      end

      def load_ids(redis_range, type_string)
         @redis.lrange(redis_range,0,-1).each_slice(100) do |slice|
          bulk = slice.collect do |id|
            obj = nil
            uri = @redis.get("aac:reverse_lookup:#{id}")            
            unless @seen_ids.include?(uri)
              @seen_ids.push(uri)
              datastring = @redis.get("aac:uri:#{uri}")
              next unless datastring
              data = JSON.parse(datastring)["@graph"].first
              data = yield(data) if block_given?
              obj = { index: { _id: uri, data: data}}
            end
            obj
          end.compact
          next if bulk.empty?
          submission = {body: bulk, index: @index, type: type_string}
          @client.bulk(submission)
        end
      end
    end
  end
end
