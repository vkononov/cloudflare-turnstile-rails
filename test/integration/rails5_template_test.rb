require 'test_helper'
require 'bundler'
require 'fileutils'

class Rails5TemplateTest < Minitest::Test
  TEMPLATE = File.expand_path('../../templates/template.rb', __dir__)

  def setup
    skip unless RUBY_VERSION < '3.0.0' && Rails::VERSION::STRING.start_with?('5.')

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

  def test_system_tests_pass_in_rails5_generated_app # rubocop:disable Metrics/MethodLength
    rails_cmd = Gem.bin_path('railties', 'rails')

    Bundler.with_unbundled_env do
      ENV['RUBYOPT'] = '-r logger -r bigdecimal'
      Dir.chdir(@tmpdir) do
        args = %w[
          new . --quiet
          --skip-git --skip-keeps
          --skip-action-mailer --skip-active-record --skip-active-storage
          --skip-action-cable --skip-spring --skip-listen --skip-coffee
          --skip-bootsnap --skip-api
        ] + ['-m', TEMPLATE]

        assert system(rails_cmd, *args), "❌ `rails new` failed: #{rails_cmd} #{args.join(' ')}"
        assert system('bundle', 'install', '--quiet'), '❌ `bundle install` failed in generated app'

        assert system('bin/rails', 'test'), '❌ tests failed in generated app'

        if Gem::Version.new(Rails::VERSION::STRING) < Gem::Version.new('5.2.0')
          assert system('bin/rails', 'test:system'), '❌ system tests failed in generated app'
        end
      end
    end
  end
end
