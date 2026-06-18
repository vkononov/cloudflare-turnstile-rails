source 'https://rubygems.org'

# Specify your gem's dependencies in cloudflare-turnstile-rails.gemspec
gemspec

# A Ruby library for testing your library against different versions of dependencies
gem 'appraisal'

# i18n 1.15.0 uses the Fiber[] storage API (Ruby 3.2+) but declares support for
# Ruby >= 3.1, so it installs and crashes on Ruby 3.1. Avoid it below 3.2.
# i18n v1.15.1 declares Ruby correctly, so only v1.15.0 needs to be excluded
gem 'i18n', '!= 1.15.0' if RUBY_VERSION < '3.2.0'

group :development do
  gem 'rake'

  # Code Linting
  gem 'rubocop', require: false
  gem 'rubocop-md', require: false
  gem 'rubocop-minitest', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rake', require: false
end

group :test do
  gem 'minitest'
  gem 'webmock'

  gem 'minitest-mock' if RUBY_VERSION >= '3.1.0'

  gem 'benchmark' if RUBY_VERSION >= '3.5.0'

  if RUBY_VERSION >= '4.0.0'
    gem 'erb', '~> 6'
  elsif RUBY_VERSION >= '3.1.0'
    gem 'erb', '~> 4'
  end
end
