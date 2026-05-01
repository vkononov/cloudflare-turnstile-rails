require_relative 'lib/cloudflare/turnstile/rails/version'

Gem::Specification.new do |spec|
  spec.name = 'cloudflare-turnstile-rails'
  spec.version = Cloudflare::Turnstile::Rails::VERSION
  spec.authors = ['Vadim Kononov']
  spec.email = ['vadim@konoson.com']

  spec.summary = 'Cloudflare Turnstile gem for Rails with built-in Turbo and Turbolinks support and CSP compliance'
  spec.description = 'Integrates Cloudflare Turnstile into Ruby on Rails applications, transparently reloads on Turbo and Turbolinks events, and embeds CSP-nonce-compliant scripts.'
  spec.homepage = 'https://github.com/vkononov/cloudflare-turnstile-rails'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.6.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/releases"

  spec.post_install_message = <<~MESSAGE
    Thanks for installing cloudflare-turnstile-rails #{Cloudflare::Turnstile::Rails::VERSION}!

    v2.0 introduced lazy mounting for the Turnstile widget. The widget no
    longer renders until it scrolls into view (or the user touches/clicks/
    types anywhere on the page), and api.js is no longer fetched on every
    page load. config.render now defaults to 'explicit' to make this safe.

    Most apps need no changes. If your v1.x config already had
    config.render = 'explicit' (and you were calling turnstile.render()
    from your own JavaScript), the gem now detects that fingerprint at
    boot and keeps lazy mounting OFF for you so your existing code keeps
    working. To opt into v2 lazy mounting, set config.lazy_mount = true.

    Full upgrade guide:

      #{spec.homepage}#upgrading-from-v1x-to-v20
  MESSAGE

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  excluded_dev_files = %w[package.json package-lock.json eslint.config.js vitest.config.js].freeze
  excluded_dev_prefixes = %w[bin/ test/ spec/ features/ templates/ .git .github appveyor Gemfile].freeze
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*excluded_dev_prefixes) || excluded_dev_files.include?(f)
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  spec.add_dependency 'rails', '>= 5.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
