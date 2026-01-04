require 'test_helper'
require 'bundler'
require 'fileutils'
require 'shellwords'

class Rails7TemplateTest < Minitest::Test
  TEMPLATE = File.expand_path('../../templates/template.rb', __dir__)

  def setup
    ruby_ok = RUBY_VERSION >= '3.1.0' && Rails::VERSION::STRING.start_with?('7.2')
    ruby_legacy_ok = RUBY_VERSION >= '2.7.0' && Rails::VERSION::STRING.start_with?(*%w[7.0 7.1])
    skip unless ruby_ok || ruby_legacy_ok

    @tmpdir = Dir.mktmpdir('cf_turnstile')
  end

  def teardown
    return unless instance_variable_defined?(:@tmpdir) && Dir.exist?(@tmpdir)

    screenshots_path = File.join(@tmpdir, 'tmp', 'screenshots')
    if Dir.exist?(screenshots_path)
      dest_dir = '/tmp/screenshots'
      FileUtils.mkdir_p(dest_dir)
      FileUtils.cp_r("#{screenshots_path}/.", dest_dir)
      puts "📸 Screenshots copied to #{dest_dir}"
    else
      puts "ℹ️ No screenshots found at #{screenshots_path}"
    end

    FileUtils.remove_entry(@tmpdir)
  end

  def test_system_tests_pass_in_rails7_generated_app # rubocop:disable Metrics/MethodLength
    rails_cmd = Gem.bin_path('railties', 'rails')
    bundle_gemfile = ENV['BUNDLE_GEMFILE']

    args = %w[
      new . --quiet
      --skip-git --skip-keeps
      --skip-action-mailer --skip-action-mailbox --skip-action-text
      --skip-active-record --skip-active-job --skip-active-storage
      --skip-action-cable --skip-jbuilder --skip-bootsnap --skip-api
    ] + ['-m', TEMPLATE]

    # On Ruby 3.2+, use bundle exec to ensure we use the correct Rails version
    # This prevents loading Rails 8.x which conflicts with erb
    if RUBY_VERSION >= '3.2.0' && bundle_gemfile
      # Run rails new with bundle exec to use Rails 7.0 from the gemfile
      # We need to preserve BUNDLE_GEMFILE for bundle exec to work
      Dir.chdir(@tmpdir) do
        ENV['RUBYOPT'] = '-r logger'
        cmd = ['bundle', 'exec', rails_cmd] + args
        assert system(*cmd), "❌ `rails new` failed: #{cmd.join(' ')}"
      end
    else
      # For older Ruby versions, use the unbundled environment
      Bundler.with_unbundled_env do
        ENV['RUBYOPT'] = '-r logger'
        Dir.chdir(@tmpdir) do
          assert system(rails_cmd, *args), "❌ `rails new` failed: #{rails_cmd} #{args.join(' ')}"
        end
      end
    end

    # Continue with bundle install and tests in unbundled environment
    Bundler.with_unbundled_env do
      Dir.chdir(@tmpdir) do
        assert system('bundle', 'install', '--quiet'), '❌ `bundle install` failed in generated app'

        # Install importmap and turbo for Rails 7.0/7.1 if needed
        if Rails::VERSION::STRING.start_with?('7') || Rails::VERSION::STRING.start_with?('7.1')
          # Check if importmap needs to be installed
          unless File.exist?('config/importmap.rb')
            system('bin/rails importmap:install') # Don't fail if task doesn't exist
          end

          # Check if turbo needs to be installed
          turbo_installed = File.exist?('app/javascript/application.js') &&
                            File.read('app/javascript/application.js').include?('turbo')
          unless turbo_installed
            system('bin/rails turbo:install') # Don't fail if task doesn't exist
          end
        end

        assert system('bin/rails', 'test:all'), '❌ tests failed in generated app'
      end
    end
  end
end
