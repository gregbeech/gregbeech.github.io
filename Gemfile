source 'https://rubygems.org'

require 'json'
require 'open-uri'
versions = JSON.parse(OpenURI.open_uri('https://pages.github.com/versions.json').read)

gem 'github-pages', versions['github-pages'], group: :jekyll_plugins

group :jekyll_plugins do
  gem 'jekyll-avatar', versions['jekyll-avatar']
  gem 'jekyll-default-layout', versions['jekyll-default-layout']
  gem 'jekyll-feed', versions['jekyll-feed']
  gem 'jekyll-gist', versions['jekyll-gist']
  gem 'jekyll-include-cache', versions['jekyll-include-cache']
  gem 'jekyll-optional-front-matter', versions['jekyll-optional-front-matter']
  gem 'jekyll-paginate', versions['jekyll-paginate']
  gem 'jekyll-readme-index', versions['jekyll-readme-index']
  gem 'jekyll-redirect-from', versions['jekyll-redirect-from']
  gem 'jekyll-relative-links', versions['jekyll-relative-links']
  gem 'jekyll-remote-theme', versions['jekyll-remote-theme']
  gem 'jekyll-seo-tag', versions['jekyll-seo-tag']
  gem 'jekyll-sitemap', versions['jekyll-sitemap']
  gem 'jekyll-titles-from-headings', versions['jekyll-titles-from-headings']
end

group :development do
  gem 'foreman'
  gem 'ruby-lsp'
end
