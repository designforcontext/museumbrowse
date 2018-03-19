require 'json'

module AAC
  module Metadata 
    def restructure_ulan_lookup!

      file = "metadata/global_results/ulan_lookup.json"
      data = JSON.parse(File.read(file))

      ulan_ids = {}
      data.each do |datum|
        return false if datum.is_a? Array
        id = datum["ulan_id"]
        ulan_ids[id] ||= []
        ulan_ids[id] << datum["actor"]
      end
      ulan_list = {entity: ulan_ids.keys.sort}

      # ulan_ids = ulan_ids.sort_by{|key,val| -val.count}

      File.open(file, "w") { |file| file.puts JSON.pretty_generate ulan_ids }
      File.open("metadata/global_results/all_ulan.json", "w") {|f| f.puts JSON.pretty_generate ulan_list} 

    end
  end
end

