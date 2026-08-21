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
    longer renders until it is needed (scrolled near, its form touched, or
    revealed from a modal), and api.js is no longer fetched on every page
    load. config.render now defaults to 'explicit' to make this safe.

    Most apps need no changes. If you call turnstile.render() from your
    own JavaScript, set config.manual_render = true: the gem will load
    api.js for you and render nothing, so your existing code keeps
    working. To get the v1.x eager rendering from the gem itself instead,
    set config.lazy_mount = false.

    Full upgrade guide:

      #{spec.homepage}#upgrading-from-v1x-to-v20
  MESSAGE

  # Ship only what the gem needs at runtime: the library code (including its
  # generators, assets, and locales) plus the license and readme. Using an
  # allowlist keeps tests, tooling, CI config, and the sample app template out
  # of the package even as new development files are added over time.
  root_files = %w[LICENSE.txt README.md]
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).select do |f|
      f.start_with?('lib/') || root_files.include?(f)
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  spec.add_dependency 'railties', '>= 5.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
