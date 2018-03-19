module LinkHelper
  # 
  # Create a link to a URL outside of the website.
  # 
  # These links will have the little icon appended and will use open in a 
  # new tab or window.  By default, it will use the URL as the text for the
  # link, but you can pass a String as a second param to it.
  #
  # If you pass it an array of URLs, it will only use the first.
  # 
  # @param url   [String]  The URL to link to.
  # @param title [String]  An optional label for the URL
  # @param opts  [Hash]    TBD.  Not currently used.
  # 
  # @return [type] [description]  
  #---------------------------------------
  def external_link_to(url, title=nil, opts = {})
    return nil if url.nil?
    url = url.first if url.is_a? Array
    title = title.first if title.is_a? Array
    title ||= url 
    "<a href='#{deprefix(url)}' target='_blank' class='external_link'>#{title || url} #{svg_icon("share")}</a>"
  end

  #---------------------------------------
  def link_to_entity(*args, &block)
    obj = args.shift
    options = args.last.is_a?(Hash) ? args.pop : {}
    label = block_given? ? capture(&block) : args.shift
    uri = settings.redis.get("aac:reverse_lookup:#{obj["id"]}")
    uri ? link_to(label, "#{uri}.html") : label
  end

  #---------------------------------------
  def link_to_foaf(obj)
    if obj.nil?
      nil
    elsif obj.is_a? String
      external_link_to(obj)   
    elsif obj.is_a? Hash
      external_link_to(obj["id"],obj["label"])   
    elsif obj.is_a? Array
      obj.map{|e| link_to_foaf(e)}
    else
      nil
    end
  end

  #---------------------------------------
  def link_to(*args, &block)
    options = args.last.is_a?(Hash) ? args.pop : {}
    link_text = block_given? ? capture(&block) : args.shift
    href = args.first
    options = { :href => href ? href : '#' }.update(options)
    if href == request.path
      options[:class] ||= []
      arr = options[:class].split(" ")
      arr << "current_link"
      options[:class] = arr.compact.uniq.join(" ")
      options[:href] = nil
      "<span #{to_attributes(options)} >#{link_text || options[:href]}</span>"
    else
      "<a #{to_attributes(options)} >#{link_text || options[:href]}</a>"
    end
  end

  # Expand a curied URI (i.e. aac:12345) into its full form.
  # 
  # If the a full http or https URI is provided, it will return that uri, 
  # and if there's a @context defined in the provided class, it will look
  # for the prefix within that context.
  # 
  # @param uri [String] The URI to expand
  # 
  # @return [String,Nil] Either a full URI or nil, if the uri cannot be expanded.
  #---------------------------------------
  def deprefix(uri)
    context = @context || [] 
    return uri if uri.nil? || uri.start_with?("http")

    arr = uri.split(":")
    replacement_value = ""
    context.each do |c|
      if c.is_a?(Hash) && c.keys.include?(arr.first)
        arr[0] = c[arr.first]
        return arr.join("")
      end
    end
    return uri
  end

  protected

  #---------------------------------------
  def to_attributes(options)
    options.map { |k, v| v.nil? ? '' : " #{k}='#{v}'" }.join
  end

  
end