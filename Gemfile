source 'https://rubygems.org'

# Specify your gem's dependencies in cloudflare-turnstile-rails.gemspec
gemspec

# A Ruby library for testing your library against different versions of dependencies
gem 'appraisal'

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

  # resolves `check_version_conflict': can't activate erb-4.0.4, already activated erb-6.0.1 (Gem::LoadError)
  gem 'erb', '~> 4' if RUBY_VERSION >= '3.1.0'
end
