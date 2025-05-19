require 'test_helper'

require 'cloudflare/turnstile/rails/configuration'

module Cloudflare
  module Turnstile
    module Rails
      class ConfigurationTest < Minitest::Test
        def setup
          # Create a fresh Configuration instance for each test
          @config = Configuration.new
        end

        def test_default_script_url
          # Test that the default script_url is set to the Cloudflare default
          assert_equal Cloudflare::SCRIPT_URL, @config.script_url
        end

        def test_custom_script_url
          # Test that when a custom script_url is provided, it is used verbatim
          custom_url = 'https://example.com/custom-api.js'
          @config.script_url = custom_url

          assert_equal custom_url, @config.script_url
        end

        def test_script_url_with_render_param
          # Test that the render parameter is added to the script_url if provided
          @config.render = 'explicit'
          expected_url = "#{Cloudflare::SCRIPT_URL}?render=explicit"

          assert_equal expected_url, @config.script_url
        end

        def test_script_url_with_onload_param
          # Test that the onload parameter is added to the script_url if provided
          @config.onload = 'onloadCallback'
          expected_url = "#{Cloudflare::SCRIPT_URL}?onload=onloadCallback"

          assert_equal expected_url, @config.script_url
        end

        def test_script_url_with_both_render_and_onload_params
          # Test that both render and onload parameters are added to the script_url
          @config.render = 'explicit'
          @config.onload = 'onloadCallback'
          expected_url = "#{Cloudflare::SCRIPT_URL}?render=explicit&onload=onloadCallback"

          assert_equal expected_url, @config.script_url
        end

        def test_script_url_with_nil_render_and_onload
          # Test that if both render and onload are nil, the default script_url is used
          @config.render = nil
          @config.onload = nil

          assert_equal Cloudflare::SCRIPT_URL, @config.script_url
        end

        def test_auto_populate_response_in_test_env
          # Test that the auto_populate_response_in_test_env is set to true by default
          assert @config.auto_populate_response_in_test_env

          # Test that the auto_populate_response_in_test_env can be set to false
          @config.auto_populate_response_in_test_env = false

          refute @config.auto_populate_response_in_test_env
        end
      end
    end
  end
end
