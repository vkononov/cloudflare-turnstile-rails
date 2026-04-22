require 'test_helper'
require 'bundler'
require 'english'
require 'fileutils'

class RailtiesOnlyTest < Minitest::Test
  GEM_ROOT = File.expand_path('../..', __dir__)

  def setup
    @tmpdir = Dir.mktmpdir('cf_turnstile_railties_only')
    @railties_constraint = "~> #{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}.0"
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if instance_variable_defined?(:@tmpdir) && Dir.exist?(@tmpdir)
  end

  def test_gem_installs_and_loads_without_rails_meta_gem # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    write_gemfile
    write_probe

    Bundler.with_unbundled_env do
      Dir.chdir(@tmpdir) do
        env = { 'BUNDLE_GEMFILE' => gemfile_path }

        assert system(env, 'bundle', 'install', '--quiet'),
               '❌ `bundle install` failed with railties-only Gemfile'

        resolved = File.read(File.join(@tmpdir, 'Gemfile.lock'))

        # The whole point of narrowing the gemspec dependency from `rails` to
        # `railties` is that Bundler must NOT pull the meta-gem (and therefore
        # must not pull ActiveRecord / ActionMailer / ActionCable / etc.).
        refute_match(/^    rails \(/, resolved,
                     "railties-only Gemfile resolved the `rails` meta-gem:\n#{resolved}")
        %w[activerecord activejob actionmailer actioncable actiontext
           activestorage actionmailbox].each do |gem_name|
          refute_match(/^    #{gem_name} \(/, resolved,
                       "railties-only Gemfile resolved `#{gem_name}`:\n#{resolved}")
        end

        # And the gem must still load and expose its Rails integration points.
        output = IO.popen(env, %w[bundle exec ruby probe.rb], err: %i[child out], &:read)

        assert_predicate $CHILD_STATUS, :success?, "❌ probe script failed:\n#{output}"

        assert_match(/^LOAD_OK$/, output, 'gem failed to load with railties-only deps')
        assert_match(/^ENGINE=Cloudflare::Turnstile::Rails::Engine$/, output)
        assert_match(/^RAILTIE=Cloudflare::Turnstile::Rails::Railtie$/, output)
        assert_match(/^HELPERS=Cloudflare::Turnstile::Rails::Helpers$/, output)
        assert_match(/^CTRL=Cloudflare::Turnstile::Rails::ControllerMethods$/, output)
        assert_match(/^GENERATOR=CloudflareTurnstile::Generators::InstallGenerator$/, output)
      end
    end
  end

  private

  def gemfile_path
    File.join(@tmpdir, 'Gemfile')
  end

  def write_gemfile
    File.write(gemfile_path, <<~RUBY)
      source 'https://rubygems.org'
      gem 'railties', '#{@railties_constraint}'
      gem 'cloudflare-turnstile-rails', path: '#{GEM_ROOT}'
    RUBY
  end

  def write_probe # rubocop:disable Metrics/MethodLength
    File.write(File.join(@tmpdir, 'probe.rb'), <<~RUBY)
      require 'rails'
      require 'action_controller/railtie'
      require 'action_view/railtie'
      require 'cloudflare/turnstile/rails'
      require 'rails/generators'
      require 'generators/cloudflare_turnstile/install_generator'

      puts 'LOAD_OK'
      puts "ENGINE="    + Cloudflare::Turnstile::Rails::Engine.name
      puts "RAILTIE="   + Cloudflare::Turnstile::Rails::Railtie.name
      puts "HELPERS="   + Cloudflare::Turnstile::Rails::Helpers.name
      puts "CTRL="      + Cloudflare::Turnstile::Rails::ControllerMethods.name
      puts "GENERATOR=" + CloudflareTurnstile::Generators::InstallGenerator.name
    RUBY
  end
end
