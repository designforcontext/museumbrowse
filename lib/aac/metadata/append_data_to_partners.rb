require 'json'
require 'csv'

module AAC
  module Metadata 
      # 
      # For a given entity, go through the `metadata/partner_data.csv file 
      # and add the additional information in that spreadsheet into the graph 
      # for that entity.
      #  
      # @param entity_uri [String] The full URI for the entity
      # @param graph [RDF::Graph] the graph which to append the data
      # 
      # @return [Void]
    def append_data_to_partners!(entity_uri, graph)

      # Load and memoize partner data CSV file.
      $partner_csv ||= CSV.read("metadata/partner_data.csv", headers: true, header_converters: :symbol)
      $partner_csv_rows ||= {}
      $partner_csv_ids ||= $partner_csv.each.collect {|r| $partner_csv_rows[r[:id]] = r; r[:id]}

      # Only do the following for IDs that appear in the spreadsheet
      # see hack note below
      return false unless $partner_csv_ids.include?(entity_uri) #|| entity_uri.include?("yale")


      # Pseudo-Prefixes
      toybox = "http://browse.americanartcollaborative.org/toybox#"
      crm = "http://www.cidoc-crm.org/cidoc-crm/"

      # Load featured objects
      all_featured_objects = CSV.foreach("metadata/featured_objects.csv").collect{|r| r[0]}
      featured_objects = all_featured_objects.find_all{ |e| e.include? entity_uri  }
      # Ugly hack for Yale's data.  I assumes that the object ID contains 
      # the partner ID.  This is not true for yale, so they never get 
      # featured items.  This also causes problems when an institution has a ULAN id.
      #
      # This should really do a reverse lookup and check for owner ID, but I'm 
      # going to be lazy right now.
      if entity_uri.include?("yale")
        featured_objects = all_featured_objects.find_all{ |e| e.include? "yale"  }
      end        

      # Set up helper objects
      row = $partner_csv_rows[entity_uri]
      s = RDF::URI.new(entity_uri)

      # Add Featured Items
      featured_p = RDF::URI.new("#{toybox}featured_items")
      featured_objects.each do |obj|
        graph.insert RDF::Statement(s, featured_p, RDF::URI.new(obj))
      end

      # Add Homepage
      graph.insert RDF::Statement(s, RDF::Vocab::FOAF.homepage, RDF::URI.new(row[:partnerprimaryweburl]))
      
      # Add Address
      c = RDF::URI.new("#{entity_uri}/main_address")
      graph.insert RDF::Statement(s, RDF::URI.new("#{crm}P76_has_contact_point"), c)
      graph.insert RDF::Statement(c, RDF.value, row[:address])
      
      # Add Description
      if row[:partnerbiodesc]
        c = RDF::URI.new("#{entity_uri}/aac_description")
        aat_desc = RDF::URI.new("http://vocab.getty.edu/aat/300080091")
        aat_pref = RDF::URI.new("http://vocab.getty.edu/aat/300404670")
        graph.insert RDF::Statement(s, RDF::Vocab::DC.description, row[:partnerbiodesc])
        graph.insert RDF::Statement(s, RDF::URI.new("#{crm}P129i_is_subject_of"), c)
        graph.insert RDF::Statement(c, RDF.type, RDF::URI.new("#{crm}E33_Linguistic_Object"))
        graph.insert RDF::Statement(c, RDF::URI.new("#{crm}P2_has_type"), aat_desc)
        graph.insert RDF::Statement(c, RDF::URI.new("#{crm}P2_has_type"), aat_pref)
        graph.insert RDF::Statement(c, RDF.value, row[:partnerbiodesc])     
      end

      # Add Content Description
      if row[:partneraaccontentdesc]
        c = RDF::URI.new("#{entity_uri}/aac_content_description")
        graph.insert RDF::Statement(s, RDF::URI.new("#{crm}P129i_is_subject_of"), c)
        graph.insert RDF::Statement(c, RDF.type, RDF::URI.new("#{crm}E33_Linguistic_Object"))
        graph.insert RDF::Statement(c, RDF::URI.new("#{crm}P2_has_type"), RDF::URI.new("#{toybox}aat_description"))
        graph.insert RDF::Statement(c, RDF.value, row[:partneraaccontentdesc])     
      end

      # Add Data Rights
      if row[:datarightsstatement]
        graph.insert RDF::Statement(s, RDF::URI.new("#{toybox}data_rights_statement"), row[:datarightsstatement])
      end

      # Add Rights URL
      if row[:partnerightsurl]
        graph.insert RDF::Statement(s, RDF::URI.new("#{toybox}data_rights_url"), RDF::URI.new(row[:partnerightsurl]))
      end
      
      # Add Logos
      if row[:logo]
        graph.insert RDF::Statement(s, RDF::URI.new("http://schema.org/logo"), row[:logo])
      end

      # [X] id
      # [ ] fullname
      # [ ] displayname
      # [ ] namepreferred
      # [X] address
      # [X] logo
      # [X] partnerprimaryweburl
      # [ ] partnercollectweburl
      # [ ] partnerightsurl
      # [X] partnerbiodesc
      # [ ] partneraaccontentdesc
      # [ ] partnerfoundyear
      # [ ] partnerparentinst
      # [ ] acronym
      # [ ] ulanid
      # [ ] truncatedpartnerlabel
      # [ ] datarootdomain
      # [ ] imagerightsstatement
      # [X] datarightsstatement

    end
  end
end
