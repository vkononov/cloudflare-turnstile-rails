require 'test_helper'
require 'bundler'
require 'fileutils'

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
    rails_version = Rails::VERSION::STRING

    Bundler.with_unbundled_env do
      ENV['RUBYOPT'] = '-r logger'
      Dir.chdir(@tmpdir) do
        args = %w[
          new . --quiet
          --skip-git --skip-keeps
          --skip-action-mailer --skip-action-mailbox --skip-action-text
          --skip-active-record --skip-active-job --skip-active-storage
          --skip-action-cable --skip-jbuilder --skip-bootsnap --skip-api
        ] + ['-m', TEMPLATE]

        # Pin railties to the version under test so `rails new` doesn't load a newer
        # railties another appraisal installed into the shared gem home.
        script = "gem 'railties', '= #{rails_version}'; load Gem.bin_path('railties', 'rails')"

        assert system('ruby', '-e', script, '--', *args), "❌ `rails new` failed: rails #{args.join(' ')}"
        assert system('bundle', 'install', '--quiet'), '❌ `bundle install` failed in generated app'
        assert system('bin/rails', 'test:all'), '❌ tests failed in generated app'
      end
    end
  end
end
