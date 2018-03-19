################################################################################
#
#    TODO:  Rewrite this
#
################################################################################

# Libraries
#---------------------------
require 'linkeddata'
require "babosa"
require "yaml"
require 'redis'
require 'pry'

require '../aac_mappings/lib/aac.rb'

module AAC
  module Utilities
    class EntityDownloader

      include AAC::Metadata

      def initialize(opts= {})
        default_options = {
          batch_size:        30,
          sparql:            "http://data.americanartcollaborative.org/sparql",
          context_uri:       "https://linked.art/ns/v1/linked-art.json",
          context_file:      "metadata/linked.art.context.json",
          verbose:           true
        }
        @options = default_options.merge(opts)

        @redis = Redis.new

        
        # Preload the JSON-LD context into memory, 
        # so we don't have to download it for every request
        context = JSON.parse(File.read(@options[:context_file]))["@context"]
        JSON::LD::Context.add_preloaded(@options[:context_uri]) do
          JSON::LD::Context.new().parse(context)
        end
        @options.delete(:context_file)

        # Load the JSON-LD prefixes into a class variable 
        context_prefixes = deep_copy(AAC::INSTITUTION_PREFIXES)
        context.each do |key, val| 
          context_prefixes[key] = val if val.is_a?(String) && val.start_with?("http")
        end
        @options[:prefixes] = context_prefixes

        # Initialize a global cache for LOD lookups.
        @external_reference_cache = {}
      end


      # For each YAML file in the `metadata/toybox` directory for the provided `type`,
      # execute the sparql CONTSTRUCT query against the given entity URI 
      # and return the results as a RDF::Graph.
      # 
      # If provided in the YAML file, this will first use the ASK query to 
      # determine if the given query is valid for the provided `entity_uri`.
      # 
      # @param entity_uri [String] The URI of the entity to run the query against
      # @param type [String] A CIDOC-CRM Type, 
      #        as expressed in the http://linked.art context file
      # 
      # @return [RDF::Graph] The results of the SPARQL CONSTRUCT query
      def do_toybox(entity_uri, type)

        graph = RDF::Graph.new
        runner = AAC::QueryRunner.new(@options[:toybox_sparql] || @options[:sparql])

        # Treat ULAN. AAT, and TGN entities as special cases
        base_type = type
        type = "Getty" if entity_uri.start_with? "http://vocab.getty.edu"

        if type == "Getty" && base_type == "Actor"
          $ulan_lookup ||= JSON.parse(File.read("metadata/global_results/ulan_lookup.json"))
          internal_links = $ulan_lookup[entity_uri]
          
          internal_links.each do |obj_id|
            obj_id = curry(obj_id)
            uri = @redis.get("aac:reverse_lookup:no_redirect:#{obj_id}")
            data = @redis.get("aac:uri:#{uri}")  
            next unless data          
            parsed_data =  JSON.parse(data)
            parsed_data["@graph"][0]["id"] = entity_uri
            parsed_data["@graph"][0].delete("exact_match")
            parsed_data["@graph"][0].delete("identified_by")
            new_graph = JSON::LD::API.toRdf(parsed_data)
            graph << new_graph
            # parsed_data = JSON.parse(data)["@graph"].first
            # parsed_data.keys.filter(|key| key.starts_with? "toybox").each do |toybox_data|

            # binding.pry
          end
        end
        Dir.glob("metadata/toybox/#{type}/*.yaml") do |file|
          sparql_query = YAML.load_file(file)
          base_query = AAC::QueryObject.new(sparql_query)
          base_query.prefixes = {
            crm: "http://www.cidoc-crm.org/cidoc-crm/", 
            toybox: "http://browse.americanartcollaborative.org/toybox#"
          }

          if sparql_query["ask"]
            valid = runner.ask (base_query.ask_query({"entity_uri" => entity_uri.strip}))
            next unless valid
          end

          current_query = base_query.construct_query({"entity_uri" => entity_uri.strip})
          graph << runner.get_graph(current_query)
        end
        graph
      end

      def download_entity(entity_uri, opts)
        # Load up the queries and the frame
        jsonld_frame = deep_copy(AAC::BASE_FRAME)
        jsonld_frame["type"] = opts[:base_crm_type]
        jsonld_frame["@context"].unshift @options[:context_uri]
        sparql_query = YAML.load_file(opts[:path_to_query])

        # Initialize the SPARQL and the query object, 
        # and set the correct CRM URI prefix 
        base_query = AAC::QueryObject.new(sparql_query)
        base_query.prefixes = {
          crm: "http://www.cidoc-crm.org/cidoc-crm/",
          aat:    "http://vocab.getty.edu/aat/",
          ulan:   "http://vocab.getty.edu/ulan/",
          gvp:   "http://vocab.getty.edu/ontology#",
          dcterms: "http://purl.org/dc/terms/",
          dc: "http://purl.org/dc/elements/1.1/",
          toybox: "http://browse.americanartcollaborative.org/toybox#"
        }

        try_count = 0
        success = false
        while try_count < 5 && !success
          begin
            puts entity_uri if @options[:verbose]

            #query the sparql endpoint
            runner     = AAC::QueryRunner.new(@options[:sparql])
            current_query = base_query.construct_query({"entity_uri" => entity_uri.strip})
            graph = runner.get_graph(current_query)
            
            # Improve the data
            # augment_with_getty_uris(graph, verbose: VERBOSE)

            append_data_to_partners!(entity_uri, graph)

            graph << do_toybox(entity_uri,opts[:base_crm_type])

            # Convert and frame the data
            jsonld = AAC::GraphUtilities.to_framed_jsonld(graph,{frame: jsonld_frame})




            # Create some useful IDs
            data       = jsonld["@graph"].first
            org_prefix = data["id"].split(":").first
            obj_id     = data["id"].split(":").last.split("/").last
            path       = "metadata/#{opts[:base_crm_type]}/#{org_prefix}/#{obj_id}.jsonld"

            # write to disk
            FileUtils.mkdir_p(File.dirname(path)) 
            File.open(path, "w+") do |file|
              file.puts JSON.pretty_generate jsonld
            end
            File.open(path.gsub("jsonld","ttl"), "w+") do |file|
              file.puts graph.dump(:ttl, prefixes: @options[:prefixes])
            end
            success = true
          rescue NoMethodError => e
            try_count = 100
            puts "generic error: #{e.inspect}"
          rescue=> e
            try_count += 1
            puts "problem with #{entity_uri}.\n\n#{e.inspect}  Retry #{try_count}."
            # puts e.backtrace
            # puts "-------------------------------------------------------\n\n"
            sleep try_count / 5.0
          end
        end

        return path
      end

      def download(opts)



        # Go through the many, many files and download them all.
        # This will do it in batches of opts[:batch_size], because
        # most of the overhead is in network requests, not in processing.
        # However, if you do more than some number, you run out of socket
        # handles, and it crashes.  
        #
        #80,000 is too many, 100 seems to work. YMMV.
        
        Thread.abort_on_exception = true  # make thread crashes crash everything.

        previous_institution = nil  
        record_counter = 0
        found_at_least_one = false
        entities = JSON.parse(File.read(opts[:path_to_uri_list]))["entity"]
        entities.each_slice(@options[:batch_size]) do |current_batch|
          found_at_least_one = false
          threads = []
          current_batch.each do |entity_uri|


            institution = entity_uri.clone
            AAC::INSTITUTION_PREFIXES.each do |prefix,uri|
              institution.gsub!(uri.to_s, "#{prefix}/")
            end
            institution, *rest = institution.split("/") 


            # Handle downloading a limited number of records per-institution
            if opts[:number_of_records] || opts[:institution]
              if opts[:institution] 
                next unless institution == opts[:institution]
              end
              if opts[:number_of_records] > 0
                if institution != previous_institution
                  previous_institution = institution
                  record_counter = 0
                end
                next unless record_counter < opts[:number_of_records] 
                record_counter+=1
              end
            end

            unless opts[:force]
              id = "#{institution}:#{rest.join("/").strip}"
              str = "aac:reverse_lookup:#{id}"
              next if @redis.get(str)
            end
            found_at_least_one = true

            # download_it
            threads << Thread.new() do
              download_entity(entity_uri,opts)
            end
          end

          # wait until this batch's threads have completed to send out a new batch.
          threads.each { |thr| thr.join }
          # sleep(1) if found_at_least_one
        end
      end

      protected
      # helper methods
      # --------------------------
      def deep_copy(o)
        Marshal.load(Marshal.dump(o))
      end

      def curry(id)
        INSTITUTION_PREFIXES.each do |prefix, url|
          id.gsub!(url, "#{prefix}:")
          id = url if id[-1]==":"
        end
        id
      end

      # --------------------------
      def augment_with_getty_uris(graph, opts)
        graph.each_statement do |triple|
          if triple.object.to_s.include? "http://vocab.getty.edu/"
            id_number = triple.object.to_s.split("/").last
            unless @external_reference_cache[id_number]
              @external_reference_cache[id_number] = RDF::Graph.load("http://lookup.davidnewbury.com/getty/#{id_number}.ttl")
              puts "caching #{id_number}" if opts[:verbose]
            end
            graph.insert(@external_reference_cache[id_number])
          end
        end
      end
    end
  end
end