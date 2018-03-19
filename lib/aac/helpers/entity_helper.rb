module EntityHelper

  #---------------------------------------
  def get_object_title(obj)
    val = display_value(by_classification(obj.dig("title"),"aat:300404670"), only_first: true)
    secondary_title = first_or_only(obj.dig("title"))
    val ||= display_value(secondary_title["value"], only_first: true) if secondary_title

    val ||= pull_field(obj, default: "(no title)", only_first: true)
    val
  end

  #---------------------------------------
  def get_actor_name(obj)
    names = display_value(by_classification(obj.dig("actor_identified_by"),"aat:300404670"), only_first: true, return_array: true)
    return names.first if names
    val = first_or_only(obj["label"])
    val = val["@value"] if val && val["@value"]
    val
  end

  #---------------------------------------
  def get_actor_bio(obj)
    bio = by_classification(obj.dig("subject_of"),"aat:300080102")
    bio ? display_value(bio, keep_newlines: true, only_longest: true) : nil
  end

  #---------------------------------------
  def best_dimension_value(obj)
    value   = dimension_to_s(obj.dig("part"))
    value ||= dimension_to_s(obj.dig("dimension"))
    value ||= by_classification(obj.dig("referred_to_by"),"aat:300266036")
    list_item "Dimensions", value, keep_newlines: true, pluralize: false
  end

  #---------------------------------------
  def dimension_to_s(dimension)
    return nil if dimension.nil?
    dims = [dimension].flatten(1)
    dims.collect do |dim|
      if dim["type"] == "PhysicalThing"
        next unless  dim["dimension"]
        str = "<div class='list_item_internal_header'>#{dim.dig("label")}</div>"
        str += "<div class='list_item_internal_list'>" + dimension_to_s(dim["dimension"]).join("<br>") + "</div>"
      else
        if dim.is_a? String
          type = nil
          unit = ""
          value = dim
        else
          begin
            unit = dim.dig("unit", "preferred_label") rescue nil
            unit ||= dim.dig("unit", "label") rescue nil
            unit ||= dim["unit"]
            if unit && unit.include?("http://qudt.org/vocab/unit#")
              unit = unit.split("#").last.downcase.pluralize(value)
            end
          rescue => e
            $logger.warn "Problem with dimension unit: #{dim}; #{e}"
            unit = ""
          end
          value = dim["value"]
          if value.is_a? Hash
            # value_type = value["type"]
            value = value["@value"].to_f
          end
          if dim["classified_as"] && dim["classified_as"].is_a?(Hash)
            type = dim.dig("classified_as","preferred_label") || dim.dig("classified_as","label") 
          end
        end
        str = ""
        str += "<span class='dimension_type'>#{type}:</span> " if type
        str += "#{value} <span class='dimension_unit'>#{unit}</span>"
        str
      end
    end
  end


#---------------------------------------
  def event_place_string(event)
    return nil if event.nil?
    if event.is_a? Array
      return event.map{|e| event_place_string(e)}.compact.uniq.sort_by{|e| e.length}.last
    end
    if place = event["took_place_at"].is_a?(Array)
      event["took_place_at"].first.dig("label")
    else
      event.dig("took_place_at","label") 
    end
  end


  # Given a E52_Time-Span, create a human-readable representation of that 
  # timespan. defaults to the rdfs:label if that exists, but will use the
  # BOTB,EOTE pair to generate a label as well.
  #
  # @param timespan [Hash] the JSON representation of an Event
  #
  # @return [String, nil] a string representing that timespan, or nil if there's
  #                       no actual dates present
  # 
#---------------------------------------
  def event_time_string(event)
    return nil if event.nil?
    if event.is_a? Array
      return event.map{|e| event_time_string(e)}.compact.uniq.sort_by{|e| e.length}.last
    end
    timespan = event["timespan"]
    # handle no data
    if timespan.nil?
      return nil

    elsif timespan.is_a? String
      $logger.debug("Timespan is a String, not an entity: #{timespan.inspect}")
      timespan  

    elsif timespan.is_a? Array
      return timespan.map{|t| event_time_string(t)}.join(", ") 
    # handle explicit label
    elsif timespan["label"]
      return  timespan["label"]
    
    # handle an entity, but one with no dates
    elsif timespan["begin_of_the_begin"].nil? && timespan["end_of_the_end"].nil?
      return nil

    # handle both are the same
    elsif timespan["begin_of_the_begin"] == timespan["end_of_the_end"] 
      return xsd_date_to_s(timespan["end_of_the_end"])

    # handle both exist
    elsif timespan["begin_of_the_end"] && timespan["end_of_the_end"]
      return "#{xsd_date_to_s(timespan["begin_of_the_begin"])} — #{xsd_date_to_s(timespan["end_of_the_end"])}"
    
    # handle only one exists
    elsif timespan["begin_of_the_end"] || timespan["end_of_the_end"]
      return xsd_date_to_s(timespan["begin_of_the_end"]) || xsd_date_to_s(timespan["end_of_the_end"])
    
    # fallback to nothing
    else
      return nil
    end
  end

  #---------------------------------------
  def xsd_date_to_s(date)
    return nil if date.nil?
    return date if date.is_a? String
    return date['@value'] if date["type"] && date["type"] == "xsd:date"
    return nil
  end
end
