require 'test_helper'
require 'stringio'

require 'cloudflare/turnstile/rails/railtie'

module Cloudflare
  module Turnstile
    module Rails
      class RailtieTest < ActiveSupport::TestCase
        setup do
          # Manually run all of our Railtie's initializers so that
          # the ActiveSupport.on_load(:action_controller) and
          # on_load(:action_view) hooks actually get registered.
          Railtie.initializers.each { |initializer| initializer.run(nil) }
          @original_config = ::Cloudflare::Turnstile::Rails.configuration
          ::Cloudflare::Turnstile::Rails.configuration = Configuration.new
          @original_logger = ::Rails.logger if ::Rails.respond_to?(:logger)
        end

        teardown do
          ::Cloudflare::Turnstile::Rails.configuration = @original_config
          ::Rails.logger = @original_logger if ::Rails.respond_to?(:logger=)
        end

        test 'defines controller_methods initializer' do
          names = Railtie.initializers.map(&:name)

          assert_includes names, 'cloudflare.turnstile.rails.controller_methods'
        end

        test 'defines helpers initializer' do
          names = Railtie.initializers.map(&:name)

          assert_includes names, 'cloudflare.turnstile.rails.helpers'
        end

        test 'defines upgrade_warning initializer' do
          names = Railtie.initializers.map(&:name)

          assert_includes names, 'cloudflare.turnstile.rails.upgrade_warning'
        end

        test 'ControllerMethods get mixed into ActionController::Base' do
          ActiveSupport.run_load_hooks(:action_controller, ActionController::Base)

          assert_includes ActionController::Base.included_modules, ControllerMethods
        end

        test 'Helpers get mixed into ActionView::Base' do
          ActiveSupport.run_load_hooks(:action_view, ActionView::Base)

          assert_includes ActionView::Base.included_modules, Helpers
        end

        test 'stays quiet on a fresh install, where render=explicit is the default' do
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_empty io.string, 'a default configuration is not misconfigured and should log nothing'
        end

        test 'warns when lazy_mount is on but render=auto leaves it nothing to defer' do
          ::Cloudflare::Turnstile::Rails.configuration.render = 'auto'
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_match(/needs an api\.js URL carrying render=explicit/, io.string)
          assert_match(%r{github\.com/vkononov/cloudflare-turnstile-rails}, io.string)
        end

        test 'warns when a custom script_url silently omits render=explicit' do
          # The URL is what actually reaches Cloudflare, so a custom one that
          # drops the parameter breaks lazy mounting just as surely as
          # render='auto' does — and used to do it without a word.
          ::Cloudflare::Turnstile::Rails.configuration.script_url = 'https://example.com/api.js'
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_match(/needs an api\.js URL carrying render=explicit/, io.string)
          assert_match(%r{https://example\.com/api\.js}, io.string, 'the offending URL should be named')
        end

        test 'stays quiet when a custom script_url carries render=explicit' do
          ::Cloudflare::Turnstile::Rails.configuration.script_url = 'https://example.com/api.js?render=explicit'
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_empty io.string
        end

        test 'does not warn when lazy_mount is disabled alongside render=auto' do
          ::Cloudflare::Turnstile::Rails.configuration.render = 'auto'
          ::Cloudflare::Turnstile::Rails.configuration.lazy_mount = false
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_empty io.string
        end

        test 'does not warn when the host app renders widgets itself' do
          ::Cloudflare::Turnstile::Rails.configuration.manual_render = true
          ::Cloudflare::Turnstile::Rails.configuration.render = 'auto'
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_empty io.string
        end

        private

        def capture_logger_output
          io = StringIO.new
          ::Rails.logger = Logger.new(io) if ::Rails.respond_to?(:logger=)
          yield
          io
        end
      end
    end
  end
end
