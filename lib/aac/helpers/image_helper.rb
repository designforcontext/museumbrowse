module ImageHelper

  #---------------------------------------
  def image_tag(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    src = args.first

    # hacks for terrible Portrait GSUB
    src.gsub!(/\.jpgf\.jpg$/,".tiff.jpg")
    src.gsub!(/\.jpgf$/,".jpg")
    
    options = { :src => src ? src : nil }.update(options)
    "<img #{to_attributes(options)} >"
  end

  #---------------------------------------
  def get_object_image(obj, redis)
    image_data = first_or_only(obj.dig("representation"))
    if image_data && image_data["value"]
      return image_data["value"]
    elsif image_data
      return deprefix(image_data["id"])
    end
    nil
  end

  #---------------------------------------
  def get_actor_image(obj, redis)
    id = obj["id"]
    uri = redis.get("aac:reverse_lookup:#{id}")

    new_obj = JSON.parse(redis.get("aac:uri:#{uri}"))["@graph"][0] rescue nil
    depicted_by =  first_or_only(new_obj.dig("depicted_by"))
    if depicted_by
      image_id = depicted_by["id"]
      uri = redis.get("aac:reverse_lookup:#{image_id}")
      image_obj = JSON.parse(redis.get("aac:uri:#{uri}"))["@graph"][0] rescue nil
      if image_obj
        image_data = first_or_only(image_obj.dig("representation")) 
        if image_data && image_data["value"]
          return  image_data["value"]
        elsif image_data 
          return deprefix(image_data["id"])
        end
      end
    end
    return nil
  end

  #---------------------------------------
  def display_image(obj, options={})

    # Evaluate options hash
    caption     = options.fetch(:caption, nil)
    link        = options.fetch(:link, false)
    thumbnail   = options.fetch(:thumbnail, false) ? "img-thumbnail" : ""
    placeholder = options.fetch(:placeholder, false)
    classes     = options.fetch(:classes, "")

    case obj["type"] 
    when "ManMadeObject"
      img = get_object_image(obj, settings.redis)
    when "Actor"
      img = get_actor_image(obj, settings.redis)
    end
    
    return nil if img.nil? && !placeholder

    str = "<figure class='figure #{classes}'>"
    if img.nil? && placeholder
      img = "/images/page_elements/no_image.png"
    end
    str += image_tag img, class: "img-fluid figure-img #{thumbnail} #{"img-placeholder" if img.nil?}"

    str += "<figcaption class='figure-caption'>#{caption}</figcaption>" if caption
    str += "</figure>"

    str = link_to_entity(obj,str) if link
    return str
  end
end