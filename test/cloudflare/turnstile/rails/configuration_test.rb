require 'test_helper'

require 'cloudflare/turnstile/rails/configuration'

module Cloudflare
  module Turnstile
    module Rails
      class ConfigurationTest < Minitest::Test
        def setup
          @config = Configuration.new
        end

        def test_default_script_url_includes_render_explicit
          # render now defaults to 'explicit' so the gem can lazy-mount safely.
          assert_equal "#{Cloudflare::SCRIPT_URL}?render=explicit", @config.script_url
        end

        def test_custom_script_url
          custom_url = 'https://example.com/custom-api.js'
          @config.script_url = custom_url

          assert_equal custom_url, @config.script_url
        end

        def test_script_url_with_render_param
          @config.render = 'explicit'
          expected_url = "#{Cloudflare::SCRIPT_URL}?render=explicit"

          assert_equal expected_url, @config.script_url
        end

        def test_script_url_with_onload_param
          # Clear render so we can test onload-only output.
          @config.render = nil
          @config.onload = 'onloadCallback'
          expected_url = "#{Cloudflare::SCRIPT_URL}?onload=onloadCallback"

          assert_equal expected_url, @config.script_url
        end

        def test_script_url_with_both_render_and_onload_params
          @config.render = 'explicit'
          @config.onload = 'onloadCallback'
          expected_url = "#{Cloudflare::SCRIPT_URL}?render=explicit&onload=onloadCallback"

          assert_equal expected_url, @config.script_url
        end

        def test_script_url_with_nil_render_and_onload
          @config.render = nil
          @config.onload = nil

          assert_equal Cloudflare::SCRIPT_URL, @config.script_url
        end

        def test_auto_populate_response_in_test_env
          assert @config.auto_populate_response_in_test_env

          @config.auto_populate_response_in_test_env = false

          refute @config.auto_populate_response_in_test_env
        end

        def test_render_default_is_explicit
          assert_equal 'explicit', @config.render
        end

        def test_lazy_mount_defaults_to_true
          assert @config.lazy_mount
        end

        def test_render_explicitly_set_sentinel
          refute_predicate @config, :render_explicitly_set?, 'expected render to start as not-explicitly-set'

          @config.render = 'explicit'

          assert_predicate @config, :render_explicitly_set?, 'expected render= to flip the sentinel'
        end

        def test_lazy_mount_explicitly_set_sentinel
          refute_predicate @config, :lazy_mount_explicitly_set?, 'expected lazy_mount to start as not-explicitly-set'

          @config.lazy_mount = true

          assert_predicate @config, :lazy_mount_explicitly_set?, 'expected lazy_mount= to flip the sentinel'
        end

        def test_effective_lazy_mount_when_render_is_explicit
          assert @config.effective_lazy_mount
        end

        def test_effective_lazy_mount_disabled_when_render_is_auto
          @config.render = 'auto'

          refute @config.effective_lazy_mount,
                 'lazy mount should degrade to false when render != explicit'
        end

        def test_effective_lazy_mount_disabled_when_lazy_mount_is_false
          @config.lazy_mount = false

          refute @config.effective_lazy_mount
        end

        def test_lazy_mount_misconfigured_combo
          # lazy_mount = true (default) + render = 'auto' is the contradictory pair.
          @config.render = 'auto'

          assert_predicate @config, :lazy_mount_misconfigured?
        end

        def test_lazy_mount_not_misconfigured_when_explicit
          assert_equal 'explicit', @config.render
          refute_predicate @config, :lazy_mount_misconfigured?
        end

        def test_lazy_mount_not_misconfigured_when_disabled
          @config.lazy_mount = false
          @config.render = 'auto'

          refute_predicate @config, :lazy_mount_misconfigured?,
                           'disabling lazy_mount should also clear the misconfiguration flag'
        end
      end
    end
  end
end
