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

        test 'emits v1-explicit upgrade warning when render=explicit is the only thing set' do
          # Fingerprint of a v1.x app that already had config.render = 'explicit'.
          ::Cloudflare::Turnstile::Rails.configuration.render = 'explicit'
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_match(/config\.lazy_mount/, io.string)
          assert_match(%r{github\.com/vkononov/cloudflare-turnstile-rails}, io.string)
        end

        test 'does not emit v1 upgrade warning on a fresh v2 install' do
          # Defaults only — render is 'explicit' implicitly, lazy_mount is true implicitly.
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          refute_match(/config\.lazy_mount/, io.string,
                       'fresh installs should not see the upgrade warning')
        end

        test 'does not emit v1 upgrade warning when lazy_mount has been explicitly set' do
          ::Cloudflare::Turnstile::Rails.configuration.render = 'explicit'
          ::Cloudflare::Turnstile::Rails.configuration.lazy_mount = false
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          refute_match(/Set\s+config\.lazy_mount/, io.string)
        end

        test 'emits combo-4 misconfiguration warning when render=auto with default lazy_mount' do
          ::Cloudflare::Turnstile::Rails.configuration.render = 'auto'
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_match(/lazy_mount = true requires/, io.string)
        end

        test 'does not emit combo-4 warning when lazy_mount is disabled alongside render=auto' do
          ::Cloudflare::Turnstile::Rails.configuration.render = 'auto'
          ::Cloudflare::Turnstile::Rails.configuration.lazy_mount = false
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          refute_match(/lazy_mount = true requires/, io.string)
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
