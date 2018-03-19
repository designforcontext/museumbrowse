module MetadataHelper

  # 
  # Generate a definition list item from a provided label and object. 
  # It has a lot of options, and will also accept any options available to 
  # #display_value.
  # 
  # @param title [String] the title of the the definition
  # @param val [Array,Hash,String,Nil] the item to display
  #
  # @param opts  [Hash] configuration options
  # @option opts [String] :class class to apply to the <dd> node 
  # @option opts [Boolean] :pluralize (true) should the label be pluralized for multiple values?
  # @option opts [Number]  :width (8) number of bootstrap columns for the <dd> node    
  # @option opts [String]  :join_char ('<br/>') what content to put between multiple values  
  # @option opts [String, Array] :title_link a link or links for the <dt> node. (If multiple, will appear as footnotes after the text.)  
  # 
  # @return [String] The HTML <dt>/<dd> pair
  #-------------------------------------------
  def list_item(title,val, opts = {})

    item_class   = opts.fetch(:class, "")
    pluralize    = opts.fetch(:pluralize, true)
    width        = opts.fetch(:width, 8)
    join_char    = opts.fetch(:join_char, "<br/>")
    title_link   = opts.fetch(:title_link, nil)


    val = display_value(val, opts.merge({return_array: true}))
    return "" if val.nil?

    title = val.count <= 1 ? title.to_s.singularize : title.to_s.pluralize if pluralize
    if title_link
      if title_link.is_a? String
        title = "<a href='#{title_link}' target='_blank'>#{title}</a>" 
      elsif title_link.is_a?(Array) && title_link.count == 1
        title = "<a href='#{title_link.first}' target='_blank'>#{title}</a>" 
      elsif title_link.is_a?(Array) && title_link.count > 1
        title_links = title_link.collect.with_index {|tl,i| "<a href='#{tl}' target='_blank'>#{i+1}</a>"}.join(", ")
        title = "#{title} (#{title_links})"
      else
        title
      end
    end
    
    str = "<dt class='col-#{12-width}'>#{title}</dt>\n"
    str << "<dd class='col-#{width} #{item_class}'>#{val.join(join_char)}</dd>"

  end 

  #-------------------------------------------
  def entity_label(obj, opts={})
    case obj["type"]
    
    when "ManMadeObject"
      str = get_object_title(obj)
      creator = if opts.fetch(:skip_person_name, false) 
        nil 
      else
        pull_field(obj.dig("produced_by", "carried_out_by"), only_first: true)      
      end
      date  = pull_field(obj.dig("produced_by", "timespan"))
      if creator || date 
        substr = [creator,date].compact.join(", ")
        str += " <span class='tombstone_artist'>(#{substr})</span>"
      end
      str
    
    when "Actor"
      str = pull_field(obj, {default: "(unknown)", only_first: true})
      nationality = by_classification(obj["member_of"], "aat:300379842", "label")
      birth = pull_field(obj.dig("brought_into_existence_by", "timespan"))
      death = pull_field(obj.dig("taken_out_of_existence_by", "timespan"))
       if nationality || birth || death 
        life_dates = [birth,death].compact.join("-")
        life_dates = life_dates.blank? ? nil : "(#{life_dates})"
        substr = [nationality,life_dates].compact.join(", ")
        str += " <span class='tombstone_artist'>#{substr}</span>"
      end
      str
    
    else 
      logger.warn "Object is not a known CIDOC entity: #{obj}"
      nil
    end
  end

  #-------------------------------------------
  def first_or_only(obj)
    [obj].flatten(1).first
  end

  #-------------------------------------------
  def get_children(obj,child_key,grandchild_key)
    val = nil
    if obj && obj[child_key]
      val = [obj[child_key]].flatten(1).collect{|o| o[grandchild_key]}.flatten.compact
    end
    val && val.empty? ? nil : val
  end

  #-------------------------------------------
  def display_value(val,opts = {})
    default_text  = opts.fetch(:default_text, "n/a")
    is_link       = opts.fetch(:is_link, false)
    field         = opts.fetch(:field, nil)
    join_char     = opts.fetch(:join_char, "<br/>")
    show_blank    = opts.fetch(:show_blank, false)
    return_array  = opts.fetch(:return_array, false)
    is_entity     = opts.fetch(:is_entity, false)
    only_first    = opts.fetch(:only_first, false)
    keep_newlines = opts.fetch(:keep_newlines, false)
    only_longest  = opts.fetch(:only_longest, false) 

    raise "Must have a field" if is_entity && !field

    return nil if !show_blank && (val.nil? || val.empty?) 
 
    if only_first && val.is_a?(Array)
      val = val.collect{|v| v.is_a?(Array) ? v.first : v}
    end
    if only_longest && val.is_a?(Array)
      val = val.collect{|v| v.is_a?(Array) ? v.sort_by{|v2| -v2.length}.first : v}.sort_by{|v2| -v2.length}.first
    end
    val = [val].flatten(1)
    if field
      val.sort_by! do |v| 
        if field == "entity" 
          entity_label(v, opts) 
        elsif v[field].is_a? String
          v[field] 
        elsif v[field].is_a? Array
          v[field].first
        else
          ""
        end
      end

      val = val.map do |v| 
        if field == "entity"
          label = entity_label(v, opts)
        else
          label = v[field]
        end

        label = label.first if label.is_a?(Array) && only_first

        if is_entity
          label = link_to_entity(v,label)
        end
        label
      end
    end

    if val.empty?
      val = ["<span class='not-available'>#{default_text}</span>"]
    elsif is_link
      val = val.map{|v| external_link_to(v)}
    elsif keep_newlines
      val = val.map do |v| 
        v.gsub("\n", "</br>").strip
        if v.start_with?("<p>") && v.end_with?("</p>")
          v = v[3...-5]
        end
        v
      end
    end
    val= val.map(&:downcase) if opts[:downcase]

    val.uniq!
    if return_array
      val
    elsif only_first
      val.first
    else
      val.join(join_char)
    end
  end

  # Retrieve the value of a crm:E55_Type that has been assigned using
  # E17_Type_Assignment with a P21_had_general_purpose.  By default, it
  # will pull the label from the type, but you can pass it another field
  # (such as `note`) if you'd prefer.
  #
  # @param obj     [Array, Hash]  the object P41i_was_classified_by
  # @param purpose [String]       the uri for the purpose 
  # @param field   [<type>]       the predicate to retrieve from the E55_Typ.
  #
  # @return [String, Array] The values for the field
  # 
  #-------------------------------------------
  def by_general_purpose(obj, purpose, field="label")
    arr = by_generic(obj, purpose, "general_purpose", "assigned_type")

    return nil if arr.nil? 

    if arr.is_a? Hash
      [arr.dig(field)]
    elsif arr.is_a? Array
      arr.map{|o| o.is_a?(Hash) ? o[field] : nil}
    end
  end


  #-------------------------------------------
  def by_classification(obj, classification, field="value") 
    by_generic(obj, classification, "classified_as", field)
  end


  #-------------------------------------------
  def except_classification(obj, classifications, field="value") 
    classifications = [classifications].flatten(1)
    results = classifications.map do |classification|
      by_generic(obj, classification, "classified_as", field, {negate: true})
    end.compact

    return nil if results.empty?
    return nil if results.length != classifications.length

    # Find the intersection of all the arrays 
    # (all objects that are in all of them)
    first_result = [results.pop].flatten(1)
     results.each do |other_result|
      first_result = [other_result].flatten(1) & first_result
    end
    first_result
  end

  #-------------------------------------------
  def by_type(obj, type, field="value") 
    by_generic(obj, type, "type", field)
  end

  protected

  # given an value, or an array of values, or a hash, return a string.
  #-------------------------------------------
  def pull_field(obj, opts = {})
    opts = {field:"label", default: nil}.merge(opts)
    val = case obj.class.to_s
      when "String" then obj
      when "Hash"   then pull_field(obj[opts[:field]], opts)   
      when "Array"
        temp = obj.collect{|a| pull_field(a,opts)}.compact
        opts[:only_first] ? temp.first : temp.join(", ")
      else nil  
    end 
    val ||= "<span class='blank_label'>#{opts[:default]}</span>" if opts[:default]
    val
  end

  #-------------------------------------------
  def by_generic(obj, generic, generic_class, field, opts= {}) 
    return nil if obj.nil? || generic.nil?

    negate = opts.fetch(:negate, false)

    arr = [obj].flatten(1).find_all do |o| 
      next unless o[generic_class]
      val = o[generic_class].include?(generic) ||
      o[generic_class].is_a?(Hash) && o[generic_class]["id"].include?(generic) ||
      o[generic_class].is_a?(Array) && o[generic_class].find_index do |sub_o| 
          (sub_o.is_a?(String) && sub_o.include?(generic)) || (sub_o.is_a?(Hash) and sub_o["id"].include?(generic))
        end
      
      negate ? !val : val
    end

    case arr.count
    when 0
      nil
    when 1
      [field].flatten(1).each{|f| return arr[0][f] if arr[0][f] }
      nil
    else
      values = []
      arr.each do |item|
        [field].flatten(1).each do |f|
           if item[f]
            values.push item[f] 
            break
          end
        end
      end
      values
    end 
  end
end

