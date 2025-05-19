require_relative 'lib/cloudflare/turnstile/rails/version'

Gem::Specification.new do |spec|
  spec.name = 'cloudflare-turnstile-rails'
  spec.version = Cloudflare::Turnstile::Rails::VERSION
  spec.authors = ['Vadim Kononov']
  spec.email = ['vadim@konoson.com']

  spec.summary = 'Simple Cloudflare Turnstile integration for Ruby on Rails.'
  spec.description = 'Integrates Cloudflare Turnstile into Rails applications, handling script injection, CSP-nonce support, and automatic Turbo/Turbolinks reinitialization.'
  spec.homepage = 'https://github.com/vkononov/cloudflare-turnstile-rails'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.6.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/releases"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ templates/ .git .github appveyor Gemfile])
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
