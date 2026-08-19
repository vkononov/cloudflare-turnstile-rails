require 'test_helper'
require 'stringio'

require 'cloudflare/turnstile/rails/railtie'

module Cloudflare
  module Turnstile
    module Rails
      # Covers Railtie.emit_upgrade_warnings, which the railtie runs once per
      # boot via an after_initialize hook. Every warning here traces back to the
      # same root cause — an api.js URL that doesn't carry render=explicit — so
      # they're grouped away from the initializer wiring tests in RailtieTest.
      class UpgradeWarningsTest < ActiveSupport::TestCase
        setup do
          @original_config = ::Cloudflare::Turnstile::Rails.configuration
          ::Cloudflare::Turnstile::Rails.configuration = Configuration.new
          @original_logger = ::Rails.logger if ::Rails.respond_to?(:logger)
        end

        teardown do
          ::Cloudflare::Turnstile::Rails.configuration = @original_config
          ::Rails.logger = @original_logger if ::Rails.respond_to?(:logger=)
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
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_empty io.string
        end

        test 'warns when the host app renders widgets itself but api.js also auto-renders' do
          # Both parties render the same element, so the app's own render() call
          # arrives second and fails. This pairing has no safe fallback, which
          # is exactly why it is worth a word at boot.
          ::Cloudflare::Turnstile::Rails.configuration.manual_render = true
          ::Cloudflare::Turnstile::Rails.configuration.render = 'auto'
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_match(/does not carry render=explicit/, io.string)
          assert_match(/300030/, io.string, 'name the error the developer will actually see')
        end

        test 'warns about manual_render when a custom script_url omits render=explicit' do
          ::Cloudflare::Turnstile::Rails.configuration.manual_render = true
          ::Cloudflare::Turnstile::Rails.configuration.script_url = 'https://example.com/api.js'
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_match(/300030/, io.string)
          assert_match(%r{https://example\.com/api\.js}, io.string, 'the offending URL should be named')
        end

        test 'emits only the manual_render warning when lazy_mount is also left on' do
          # manual_render wins the mode resolution (:passive), so the lazy-mount
          # advice would be misleading noise here.
          ::Cloudflare::Turnstile::Rails.configuration.manual_render = true
          ::Cloudflare::Turnstile::Rails.configuration.render = 'auto'
          io = capture_logger_output do
            Railtie.emit_upgrade_warnings
          end

          assert_match(/300030/, io.string)
          refute_match(/the lazy-mount triggers have nothing left to defer/, io.string)
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
