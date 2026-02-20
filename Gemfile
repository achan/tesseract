source "https://rubygems.org"

gem "rails", "~> 8.0.2"
gem "minitest", "~> 5.25"
gem "propshaft"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "tailwindcss-rails"

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "mission_control-jobs"

gem "dotenv-rails"

gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

gem "slack-ruby-client", "~> 3.1"
gem "redcarpet", "~> 3.6"
gem "gemoji", "~> 4.1"
