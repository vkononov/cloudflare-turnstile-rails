require 'test_helper'

require 'cloudflare/turnstile/rails/configuration'

class ConfigurationTest < Minitest::Test
  def setup
    # Create a fresh Configuration instance for each test
    @config = Cloudflare::Turnstile::Rails::Configuration.new
  end

  def test_default_script_url
    # Test that the default script_url is set to the Cloudflare default
    assert_equal Cloudflare::Turnstile::Rails::Cloudflare::SCRIPT_URL, @config.script_url
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
    expected_url = "#{Cloudflare::Turnstile::Rails::Cloudflare::SCRIPT_URL}?render=explicit"

    assert_equal expected_url, @config.script_url
  end

  def test_script_url_with_onload_param
    # Test that the onload parameter is added to the script_url if provided
    @config.onload = 'onloadCallback'
    expected_url = "#{Cloudflare::Turnstile::Rails::Cloudflare::SCRIPT_URL}?onload=onloadCallback"

    assert_equal expected_url, @config.script_url
  end

  def test_script_url_with_both_render_and_onload_params
    # Test that both render and onload parameters are added to the script_url
    @config.render = 'explicit'
    @config.onload = 'onloadCallback'
    expected_url = "#{Cloudflare::Turnstile::Rails::Cloudflare::SCRIPT_URL}?render=explicit&onload=onloadCallback"

    assert_equal expected_url, @config.script_url
  end

  def test_script_url_with_nil_render_and_onload
    # Test that if both render and onload are nil, the default script_url is used
    @config.render = nil
    @config.onload = nil

    assert_equal Cloudflare::Turnstile::Rails::Cloudflare::SCRIPT_URL, @config.script_url
  end

  def test_validation_with_valid_keys
    # Test that no error is raised if valid site_key and secret_key are set
    @config.site_key = 'valid_site_key'
    @config.secret_key = 'valid_secret_key'

    assert_nil @config.validate!
  end

  def test_validation_with_missing_site_key
    # Test that an error is raised when site_key is missing
    @config.site_key = nil
    @config.secret_key = 'valid_secret_key'
    assert_raises(Cloudflare::Turnstile::Rails::ConfigurationError, 'Cloudflare Turnstile site_key is not set.') do
      @config.validate!
    end
  end

  def test_validation_with_missing_secret_key
    # Test that an error is raised when secret_key is missing
    @config.site_key = 'valid_site_key'
    @config.secret_key = nil
    assert_raises(Cloudflare::Turnstile::Rails::ConfigurationError, 'Cloudflare Turnstile secret_key is not set.') do
      @config.validate!
    end
  end

  def test_validation_with_both_keys_missing
    # Test that an error is raised when both keys are missing
    @config.site_key = nil
    @config.secret_key = nil
    assert_raises(Cloudflare::Turnstile::Rails::ConfigurationError, 'Cloudflare Turnstile site_key is not set.') do
      @config.validate!
    end
  end
end
