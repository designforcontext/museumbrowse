module ToyboxHelper
  
  #---------------------------------------
  def split_by_owner(works)  
    owners = {}
    works = [works] if works.is_a?(Hash)
    works.each do |work|
      owner = work["current_owner"]["label"]
      owners[owner] ||= []
      owners[owner] << work
    end
    owners.sort_by{|key,val| val.length}.to_h    
  end

  #---------------------------------------
  def get_relationship_list(people)
    list = {}
    [people].flatten(1).each do |item|
      next unless  item["toybox:related_actor"]
      id = item["toybox:related_actor"]["id"]
      uri = settings.redis.get("aac:reverse_lookup:#{id}")
      person = JSON.parse(settings.redis.get("aac:uri:#{uri}"))["@graph"][0] rescue nil
      if person
        reltype = item["toybox:relationship_label"].split(" - ").first
        link = link_to_entity(person, get_actor_name(person))
        list[reltype] ||= []
        list[reltype] << link
      end
    end
    list
  end
end