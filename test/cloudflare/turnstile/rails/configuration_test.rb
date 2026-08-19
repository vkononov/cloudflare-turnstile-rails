require 'test_helper'

require 'cloudflare/turnstile/rails/configuration'

module Cloudflare
  module Turnstile
    module Rails
      class ConfigurationTest < Minitest::Test # rubocop:disable Metrics/ClassLength
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

        def test_default_data_defaults_to_empty_hash
          assert_empty(@config.default_data)
        end

        def test_default_data_is_configurable
          @config.default_data = { theme: 'dark' }

          assert_equal({ theme: 'dark' }, @config.default_data)
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

        def test_manual_render_defaults_to_false
          refute @config.manual_render
        end

        def test_reserve_space_defaults_to_true
          assert @config.reserve_space
        end

        def test_explicit_render_is_true_for_the_default_url
          assert_predicate @config, :explicit_render?
        end

        def test_explicit_render_is_false_when_render_is_auto
          @config.render = 'auto'

          refute_predicate @config, :explicit_render?
        end

        def test_explicit_render_is_false_for_a_custom_url_without_the_param
          # A custom script_url is used verbatim, so config.render never reaches
          # the URL. Reading @render here would wrongly claim explicit rendering.
          @config.script_url = 'https://example.com/custom-api.js'

          assert_equal 'explicit', @config.render
          refute_predicate @config, :explicit_render?,
                           'explicit_render? must describe the URL we actually load, not config.render'
        end

        def test_explicit_render_is_true_for_a_custom_url_carrying_the_param
          @config.script_url = 'https://example.com/custom-api.js?render=explicit&foo=bar'

          assert_predicate @config, :explicit_render?
        end

        def test_explicit_render_is_false_for_an_unparseable_url
          @config.script_url = 'https://exa mple.com/api.js'

          refute_predicate @config, :explicit_render?, 'a URL we cannot parse must not be trusted as explicit'
        end

        def test_effective_mount_mode_defaults_to_lazy
          assert_equal :lazy, @config.effective_mount_mode
        end

        def test_effective_mount_mode_is_eager_when_lazy_mount_is_false
          @config.lazy_mount = false

          assert_equal :eager, @config.effective_mount_mode,
                       'disabling lazy mounting must still leave the gem rendering widgets'
        end

        def test_effective_mount_mode_is_eager_when_render_is_auto
          @config.render = 'auto'

          assert_equal :eager, @config.effective_mount_mode
        end

        def test_effective_mount_mode_is_eager_for_a_custom_url_without_explicit
          @config.script_url = 'https://example.com/custom-api.js'

          assert_equal :eager, @config.effective_mount_mode
        end

        def test_effective_mount_mode_is_passive_when_manual_render
          @config.manual_render = true

          assert_equal :passive, @config.effective_mount_mode
        end

        def test_manual_render_takes_precedence_over_lazy_mount
          @config.manual_render = true
          @config.lazy_mount = true

          assert_equal :passive, @config.effective_mount_mode
        end

        def test_lazy_mount_misconfigured_when_render_is_auto
          @config.render = 'auto'

          assert_predicate @config, :lazy_mount_misconfigured?
        end

        def test_lazy_mount_misconfigured_for_a_custom_url_without_explicit
          @config.script_url = 'https://example.com/custom-api.js'

          assert_predicate @config, :lazy_mount_misconfigured?,
                           'a custom URL that omits render=explicit silently breaks lazy mounting, so warn'
        end

        def test_lazy_mount_not_misconfigured_when_explicit
          refute_predicate @config, :lazy_mount_misconfigured?
        end

        def test_lazy_mount_not_misconfigured_when_disabled
          @config.lazy_mount = false
          @config.render = 'auto'

          refute_predicate @config, :lazy_mount_misconfigured?,
                           'disabling lazy_mount should also clear the misconfiguration flag'
        end

        def test_lazy_mount_not_misconfigured_when_rendering_manually
          @config.manual_render = true
          @config.render = 'auto'

          refute_predicate @config, :lazy_mount_misconfigured?,
                           'manual_render opts out of mounting entirely, so lazy_mount is moot'
        end

        def test_manual_render_misconfigured_when_render_is_auto
          @config.manual_render = true
          @config.render = 'auto'

          assert_predicate @config, :manual_render_misconfigured?,
                           'Cloudflare auto-renders and so does the app, which is error 300030'
        end

        def test_manual_render_misconfigured_for_a_custom_url_without_explicit
          @config.manual_render = true
          @config.script_url = 'https://example.com/custom-api.js'

          assert_predicate @config, :manual_render_misconfigured?
        end

        def test_manual_render_not_misconfigured_when_explicit
          @config.manual_render = true

          refute_predicate @config, :manual_render_misconfigured?,
                           'render=explicit leaves the app as the only party rendering, which is the point'
        end

        def test_manual_render_not_misconfigured_when_the_gem_still_renders
          @config.render = 'auto'

          refute_predicate @config, :manual_render_misconfigured?,
                           'without manual_render nobody is competing with the auto-render observer'
        end

        def test_reserve_space_only_applies_in_lazy_mode
          assert_predicate @config, :reserve_space?

          @config.lazy_mount = false

          refute_predicate @config, :reserve_space?,
                           'eager mode has the iframe on its way before first paint, so there is no shift'
        end

        def test_reserve_space_can_be_switched_off
          @config.reserve_space = false

          refute_predicate @config, :reserve_space?
        end

        def test_reserve_space_per_tag_override_wins_over_the_global_setting
          @config.reserve_space = false

          assert @config.reserve_space?(true), 'reserve_space: true should re-enable reservation for one tag'

          @config.reserve_space = true

          refute @config.reserve_space?(false), 'reserve_space: false should disable reservation for one tag'
        end

        def test_reserve_space_override_cannot_resurrect_a_non_lazy_mode
          @config.lazy_mount = false

          refute @config.reserve_space?(true),
                 'there is no layout shift to absorb outside lazy mode, whatever the caller asks for'
        end

        def test_nil_reserve_space_override_defers_to_the_global_setting
          assert @config.reserve_space?(nil)

          @config.reserve_space = false

          refute @config.reserve_space?(nil)
        end
      end
    end
  end
end
