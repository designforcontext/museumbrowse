source 'https://rubygems.org'
ruby "2.5.0"

## Linked Data Gems
##--------------------------------------------------
gem "linkeddata"
gem "diffy"
# gem "sparql-client", git: "git@github.com:ruby-rdf/sparql-client.git", branch: "master"
# gem "net-http-persistent", "3.0"


## Gems for Rack
##--------------------------------------------------
gem "rack"
gem 'rack-cors', :require => 'rack/cors'

## Caching
##--------------------------------------------------
gem 'redis'
gem "rack-cache"
# gem 'redis-rack-cache'

## Search
##--------------------------------------------------
gem 'elasticsearch'
gem "elasticsearch-extensions"

## Gems for Sintatra
##--------------------------------------------------
gem "sinatra"
gem "sinatra-contrib"
gem 'puma'

## View/Presenation Layer Gems
##--------------------------------------------------
gem "haml", "~> 5.0"
gem "sass"
gem "activesupport"
gem "babosa"
gem 'commonmarker'
gem 'front_matter_parser'

## Build-only Gems
##--------------------------------------------------
group :test, :development do
  gem "rake"
  gem "pry"
  gem 'guard'
  gem 'guard-sass', :require => false
  gem 'dotenv'
  gem 'foreman'
  gem 'yard'
  gem 'sitemap_generator'
  gem 'sitemap-parser'
  gem 'typhoeus'
end