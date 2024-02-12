source 'https://rubygems.org'

gemspec

case ENV.fetch('RAILS', 'latest')
when 'latest'
  gem 'activemodel'
  gem 'actionpack'
when 'head'
  gem 'activemodel', github: 'rails/rails'
  gem 'actionpack', github: 'rails/rails'
else
  gem 'activemodel', ENV.fetch('RAILS', nil)
  gem 'actionpack', ENV.fetch('RAILS', nil)
end

gem "bundler"
gem "rspec", "~> 3.0"
gem "pry"
gem "rake"
gem "yard"
