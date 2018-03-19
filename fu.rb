require 'json'

data = JSON.parse(File.read("metadata/global_results/ulan_lookup.json"))
data.keys.each do |key|
  str = "rake ulan[#{key}]"
  # puts str
  puts `#{str}`
end