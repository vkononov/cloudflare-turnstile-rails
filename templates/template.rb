# 1) allow `copy_file`/`directory` to find files in templates/shared
shared = File.expand_path('shared', __dir__)
source_paths.unshift(shared)

# 2) inject our gem under test into the Gemfile
append_to_file 'Gemfile', <<~RUBY
  gem 'appraisal', require: false
  gem 'minitest-retry', require: false
  gem 'rails-controller-testing'

  if RUBY_VERSION >= '3.0.0'
    # Include gems that are no longer loaded from standard libraries
    gem 'mutex_m'
    gem 'bigdecimal'
    gem 'drb'
    gem 'benchmark'
  end

  # Resolve the "uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger (NameError)" issue
  gem 'concurrent-ruby', '< 1.3.5'

  # Rails currently has an incompatibility with minitest v6
  gem 'minitest', '< 6.0.0'

  #{if Rails::VERSION::STRING < '7.0.0'
      "# Higher versions are unsupported in Rails < 7.0.0\n# gem 'minitest', '< 5.12'"
    end}#{'  '}
  #{if Rails::VERSION::STRING < '7.2.0'
      "# Higher versions cause 'uninitialized constant Rack::Handler (NameError)'\ngem 'rack', '< 3.0.0'"
    end}#{'  '}

  if RUBY_VERSION >= '3.1.0'
    # Resolve the "Unknown alias: default (Psych::BadAlias)" error
    gem 'psych', '< 4'
  end

  #{if Rails::VERSION::STRING.start_with?('5.2.')
      "# Required for Rails 5.2, unsupported in older versions, and deprecated in newer versions\ngem 'webdrivers'"
    end}#{'  '}

  # test against the local checkout of cloudflare-turnstile-rails
  gem 'cloudflare-turnstile-rails', path: "#{File.expand_path('..', __dir__)}"
RUBY

# 3) copy over all the shared app files
%w[
  app/controllers/pages_controller.rb
  app/controllers/books_controller.rb.tt
  app/models/book.rb.tt
  app/views/pages/home.html.erb
  app/views/books/create.js.erb
  app/views/books/_form.html.erb
  app/views/books/new.html.erb
  app/views/books/new2.html.erb
  config/initializers/cloudflare_turnstile.rb
  config/initializers/content_security_policy.rb
  config/routes.rb
  test/application_system_test_case.rb
  test/controllers/books_controller_test.rb.tt
  test/system/books_test.rb
].each do |shared_path|
  if shared_path.end_with?('.tt')
    template shared_path, shared_path.sub(/\.tt$/, ''), force: true
  else
    copy_file shared_path, shared_path, force: true
  end
end

# 4) configure minitest-retry in test_helper.rb
gsub_file 'test/test_helper.rb', %r{require ['"]rails/test_help['"]\n},
          "\\0require 'minitest/retry'\n\nMinitest::Retry.use! if ENV['CI'].present?\n"

# 5) turbo AJAX-cache helper
packer_js = 'app/javascript/packs/application.js'
if File.exist?(packer_js)
  copy_file 'cloudflare_turbolinks_ajax_cache.js', 'app/javascript/packs/cloudflare_turbolinks_ajax_cache.js',
            force: true

  # import it at the very bottom of application.js
  import_line = "\n// restore cached pages on AJAX navigations\n" \
                "import './cloudflare_turbolinks_ajax_cache'\n"
  append_to_file packer_js, import_line
end

# 6) Remove any existing chromedriver-helper gem line from Gemfile (only relevant for Rails 5.x)
gsub_file 'Gemfile', /^\s*gem ['"]chromedriver-helper['"].*\n/, ''
