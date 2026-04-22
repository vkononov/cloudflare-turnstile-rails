require 'test_helper'
require 'bundler'
require 'fileutils'

class RailtiesOnlyTest < Minitest::Test
  GEM_ROOT = File.expand_path('../..', __dir__)

  def setup
    @tmpdir = Dir.mktmpdir('cf_turnstile_railties_only')
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if instance_variable_defined?(:@tmpdir) && Dir.exist?(@tmpdir)
  end

  def test_railties_only_gemfile_does_not_resolve_rails_meta_gem # rubocop:disable Metrics/MethodLength
    write_gemfile

    Bundler.with_unbundled_env do
      Dir.chdir(@tmpdir) do
        env = { 'BUNDLE_GEMFILE' => File.join(@tmpdir, 'Gemfile') }

        assert system(env, 'bundle', 'install', '--quiet'),
               'bundle install failed with railties-only Gemfile'

        resolved = File.read(File.join(@tmpdir, 'Gemfile.lock'))

        # Narrowing the gemspec dependency from `rails` to `railties` means
        # Bundler must not pull the meta-gem or any Rails components the gem
        # does not actually use.
        refute_match(/^    rails \(/, resolved,
                     "railties-only Gemfile resolved the `rails` meta-gem:\n#{resolved}")
        %w[activerecord activejob actionmailer actioncable actiontext
           activestorage actionmailbox].each do |gem_name|
          refute_match(/^    #{gem_name} \(/, resolved,
                       "railties-only Gemfile resolved `#{gem_name}`:\n#{resolved}")
        end
      end
    end
  end

  private

  def write_gemfile
    constraint = "~> #{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}.0"
    File.write(File.join(@tmpdir, 'Gemfile'), <<~RUBY)
      source 'https://rubygems.org'
      gem 'railties', '#{constraint}'
      gem 'cloudflare-turnstile-rails', path: '#{GEM_ROOT}'
    RUBY
  end
end
