module IconHelper
  
  #
  # Insert a SVG icon directly into the HTML.  If you pass a string
  # that doesn't exist, it will put a big ugly red error into your page.
  # 
  # @param icon [string] The filename of the icon (without extension)
  # 
  # @return [string] The raw SVG code of that icon
  def svg_icon(icon)
    begin
      File.read("source/public/images/icons/#{icon}.svg")
    rescue
      "<div class='code-error'>'#{icon}' icon missing</div>"
    end
  end
end