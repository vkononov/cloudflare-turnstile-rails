require 'test_helper'

require 'cloudflare/turnstile/rails/controller_methods'
require 'cloudflare/turnstile/rails/constants/cloudflare'
require 'cloudflare/turnstile/rails/constants/error_code'
require 'cloudflare/turnstile/rails/constants/error_message'
require 'cloudflare/turnstile/rails/verification'

class ControllerMethodsTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  include Cloudflare::Turnstile::Rails::ControllerMethods

  # Dummy model with minimal .errors interface
  class DummyErrors
    attr_reader :added

    def initialize
      @added = []
    end

    def add(attr, msg)
      @added << [attr, msg]
    end
  end

  class DummyModel
    attr_reader :errors

    def initialize
      @errors = DummyErrors.new
    end
  end

  def setup
    @model = DummyModel.new
    @params = {}
    singleton_class.define_method(:params) { @params }
  end

  def teardown
    singleton_class.send(:remove_method, :params)
  end

  def test_returns_false_and_adds_error_when_token_missing
    code = Cloudflare::Turnstile::Rails::ErrorCode::MISSING_INPUT_RESPONSE
    message = Cloudflare::Turnstile::Rails::ErrorMessage.for(code)
    @params.clear
    result = verify_turnstile(model: @model)

    refute result
    assert_equal [[:base, message]], @model.errors.added
  end

  def test_successful_verification_returns_response
    fake_resp = Cloudflare::Turnstile::Rails::VerificationResponse.new({ 'success' => true })
    Cloudflare::Turnstile::Rails::Verification.stub(:verify, fake_resp) do
      @params[Cloudflare::Turnstile::Rails::Cloudflare::RESPONSE_FIELD_NAME] = 'tok123'
      result = verify_turnstile(model: @model)

      assert_equal fake_resp, result
      assert_empty @model.errors.added
    end
  end

  def test_verification_failure_adds_mapped_error
    code = Cloudflare::Turnstile::Rails::ErrorCode::TIMEOUT_OR_DUPLICATE
    message = Cloudflare::Turnstile::Rails::ErrorMessage.for(code)
    fake_resp = Cloudflare::Turnstile::Rails::VerificationResponse.new({ 'success' => false, 'error-codes' => [code] })
    Cloudflare::Turnstile::Rails::Verification.stub(:verify, fake_resp) do
      @params[Cloudflare::Turnstile::Rails::Cloudflare::RESPONSE_FIELD_NAME] = 'tok123'
      result = verify_turnstile(model: @model)

      refute result
      assert_equal [[:base, message]], @model.errors.added
    end
  end

  def test_verification_failure_uses_default_error_for_unknown_code
    code = 'unknown-error'
    default_msg = Cloudflare::Turnstile::Rails::ErrorMessage.for(code)
    fake_resp = Cloudflare::Turnstile::Rails::VerificationResponse.new({ 'success' => false, 'error-codes' => [code] })
    Cloudflare::Turnstile::Rails::Verification.stub(:verify, fake_resp) do
      @params[Cloudflare::Turnstile::Rails::Cloudflare::RESPONSE_FIELD_NAME] = 'tok123'
      result = verify_turnstile(model: @model)

      refute result
      assert_equal [[:base, default_msg]], @model.errors.added
    end
  end

  def test_verify_turnstile_passes_options_to_verify # rubocop:disable Metrics/MethodLength
    captured = {}
    fake_resp = Cloudflare::Turnstile::Rails::VerificationResponse.new({ 'success' => true })
    Cloudflare::Turnstile::Rails::Verification.stub(:verify, lambda { |**opts|
      captured.merge!(opts)
      fake_resp
    }) do
      @params[Cloudflare::Turnstile::Rails::Cloudflare::RESPONSE_FIELD_NAME] = 'tok123'
      result = verify_turnstile(
        model: @model,
        secret: 'sk',
        response: 'explicit',
        remoteip: '1.2.3.4',
        idempotency_key: 'my-key'
      )

      assert_equal fake_resp, result
      assert_equal 'sk',          captured[:secret]
      assert_equal 'explicit',    captured[:response]
      assert_equal '1.2.3.4',     captured[:remoteip]
      assert_equal 'my-key',      captured[:idempotency_key]
    end
  end

  def test_model_optional_on_missing_token
    @params.clear
    result = verify_turnstile(model: nil)

    refute result
  end

  def test_returns_response_for_model_nil_on_success
    fake_resp = Cloudflare::Turnstile::Rails::VerificationResponse.new({ 'success' => true })
    Cloudflare::Turnstile::Rails::Verification.stub(:verify, fake_resp) do
      @params[Cloudflare::Turnstile::Rails::Cloudflare::RESPONSE_FIELD_NAME] = 'tok123'
      result = verify_turnstile(model: nil)

      assert_equal fake_resp, result
    end
  end

  def test_verify_turnstile_rescues_configuration_error
    err = Cloudflare::Turnstile::Rails::ConfigurationError.new('something went wrong')
    Cloudflare::Turnstile::Rails::Verification.stub(:verify, ->(**) { raise err }) do
      @params[Cloudflare::Turnstile::Rails::Cloudflare::RESPONSE_FIELD_NAME] = 'tok123'

      result = verify_turnstile(model: @model)

      refute result
      assert_equal [[:base, 'something went wrong']], @model.errors.added
    end
  end

  def test_missing_secret_in_configuration
    code    = Cloudflare::Turnstile::Rails::ErrorCode::MISSING_INPUT_SECRET
    message = Cloudflare::Turnstile::Rails::ErrorMessage.for(code)
    Cloudflare::Turnstile::Rails.configuration.secret_key = nil
    @params[Cloudflare::Turnstile::Rails::Cloudflare::RESPONSE_FIELD_NAME] = 'tok123'

    result = verify_turnstile(model: @model)

    refute result

    assert_equal [[:base, message]], @model.errors.added
  end

  def test_explicit_response_argument_overrides_params
    fake_resp = Cloudflare::Turnstile::Rails::VerificationResponse.new('success' => true)
    captured = {}

    Cloudflare::Turnstile::Rails::Verification.stub(:verify, lambda { |**opts|
      captured.merge!(opts)
      fake_resp
    }) do
      result = verify_turnstile(model: @model, response: 'explicit-token')

      assert_equal fake_resp, result
      assert_equal 'explicit-token', captured[:response]
    end
  end
end
