# American Art Collaborative Browse Application

This is the source code for the Browse Application for the American Art Collaborative, a Mellon and IMLS-funded consortium of 14 art museums in the United States committed to establishing a critical mass of linked open data (LOD) on the semantic web.

This portion of the project is designed to explore techniques for building large scale web applications on top of heterogeneous linked data. One of the major complications of using Linked Data in this way is that it is not traditionally designed to function as quickly as we've become accustomed to.

## Technical Details

The site is implemented using [Sinatra](http://www.sinatrarb.com/), a micro-framework for web applications using the [Ruby Programming Language](https://www.ruby-lang.org/en/).   However, the site is not designed to be run in production using Sinatra—instead, the site is designed to use Sinatra as a static site generator.  This novel pipeline, combined with aggressive use of [Redis](https://redis.io/) as a local cache allows the entire site to be developed locally with the performance of a dynamic website, but deployed as a large, static HTML site.

Building the site this way is designed to take into consideration the often limited maintenance resources available for projects like this in Cultural Heritage.

## Installation

These installation instructions have been tested on MacOS, but should work in principal (if not in the details) on any system.

    rvm install ruby-2.5.0
    brew install elasticsearch
    brew install redis
    brew install yarn
    gem install foreman
    gem install bundler
    bundle instal
    yarn install


## Running the Site in Development

    foreman start

## Deploying the Site

    foreman start
    rake deploy

---
