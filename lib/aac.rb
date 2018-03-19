# Load sub-files from the lib/aac directory
Dir.glob("#{__dir__}/aac/**/*.rb") { |file| require file}


module AAC 
   INSTITUTION_PREFIXES = {
      "cbm"=>   "http://data.crystalbridges.org/",                   # Crystal Bridges
      "wam"=>   "http://data.thewalters.org/",                       # Walters
      "ccma"=>  "http://data.museum.colby.edu/aac/",                 # Colby College
      "ycba"=>  "http://collection.britishart.yale.edu/id/",         # YCBA
      "aaa"=>   "http://data.americanartcollaborative.org/aaa",      # Archives of American Art
      "puam"=>  "http://data.americanartcollaborative.org/puam/",    # Princeton
      "gm"=>    "http://data.gilcrease.org/",                        # Gilcrease
      "acm"=>   "http://data.cartermuseum.org/",                     # Aaron Carter
      "autry"=> "http://data.theautry.org/",                         # Autry
      "nmwa"=>  "http://data.wildlifeart.org/",                      # National Wildlife
      "npg"=>   "http://data.npg.si.edu/",                           # National Portrait Gallery
      "ima"=>   "http://data.imamuseum.org/",                        # Indianapolis
      "saam"=>  "http://data.americanart.si.edu/",                   # Smithsonian American Art
      "dma"=>   "http://data.americanartcollaborative.org/dma/",     # Dallas 
      "ulan"=>  "http://vocab.getty.edu/ulan/",                      # ULAN
      "aat"=>  "http://vocab.getty.edu/aat/"                         # AAT
    }

    ADDITIONAL_CONTEXT = {
      "xsd"=>   "http://www.w3.org/2001/XMLSchema#",
      "vocabulary"=> "skos:inScheme",
      "toybox"=>  "http://browse.americanartcollaborative.org/toybox#",
      "preferred_label"=> "skos:prefLabel",
      "begin_of_the_begin"=> {
        "@id"=> "crm:P82a_begin_of_the_begin"
      },
      "end_of_the_end"=> {
        "@id"=> "crm:P82b_end_of_the_end"
      }
    }

    BASE_FRAME = {
      "@context"=> [
        AAC::INSTITUTION_PREFIXES,
        AAC::ADDITIONAL_CONTEXT
      ],
      "@embed"=> "@always",
    }

    MAN_MADE_OBJECT = {
      path_to_query:     "metadata/queries/mmo.yaml",
      path_to_uri_list:  "metadata/global_results/all_mmos.json",
      base_crm_type:     "ManMadeObject"
    }
    ACTOR = {
      path_to_query:     "metadata/queries/actor.yaml",
      path_to_uri_list:  "metadata/global_results/all_actors.json",
      base_crm_type:     "Actor"
    }
    ULAN_ACTOR = {
      path_to_query:     "metadata/queries/ulan_actor.yaml",
      path_to_uri_list:  "metadata/global_results/all_ulan.json",
      base_crm_type:     "Actor"
    }
    AAT = {
      path_to_query:     "metadata/queries/aat.yaml",
      path_to_uri_list:  "metadata/global_results/all_aat.json",
      base_crm_type:     "Type"
    }

end

