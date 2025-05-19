require 'test_helper'

require 'cloudflare/turnstile/rails/controller_methods'
require 'cloudflare/turnstile/rails/constants/cloudflare'
require 'cloudflare/turnstile/rails/constants/error_code'
require 'cloudflare/turnstile/rails/constants/error_message'
require 'cloudflare/turnstile/rails/verification'

module Cloudflare
  module Turnstile
    module Rails
      class ControllerMethodsTest < Minitest::Test
        include ControllerMethods

        # –– Dummy model with minimal .errors interface ––#
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

        def test_missing_response_raises
          err = assert_raises(ConfigurationError) { verify_turnstile(model: @model) }
          assert_equal ErrorMessage.for(ErrorCode::MISSING_INPUT_RESPONSE), err.message
        end

        def test_missing_secret_raises
          @params[Cloudflare::RESPONSE_FIELD_NAME] = 'tok'
          Rails.configuration.secret_key = nil
          err = assert_raises(ConfigurationError) { verify_turnstile(model: @model, response: 'tok') }
          assert_equal ErrorMessage.for(ErrorCode::MISSING_INPUT_SECRET), err.message
        end

        def test_successful_verification_returns_response
          fake = VerificationResponse.new({ 'success' => true })
          Verification.stub(:verify, fake) do
            @params[Cloudflare::RESPONSE_FIELD_NAME] = 'tok'
            result = verify_turnstile(model: @model)

            assert_equal fake, result
            assert_empty @model.errors.added
          end
        end

        def test_valid_turnstile_on_success
          fake = VerificationResponse.new({ 'success' => true })
          Verification.stub(:verify, fake) do
            @params[Cloudflare::RESPONSE_FIELD_NAME] = 'tok'

            assert valid_turnstile?(model: @model)
          end
        end

        def test_verification_failure_adds_mapped_error
          code = ErrorCode::TIMEOUT_OR_DUPLICATE
          message = ErrorMessage.for(code)

          fake = VerificationResponse.new({ 'success' => false, 'error-codes' => [code]})
          Verification.stub(:verify, fake) do
            @params[Cloudflare::RESPONSE_FIELD_NAME] = 'tok'
            result = verify_turnstile(model: @model)

            refute_predicate result, :success?
            assert_equal [[:base, message]], @model.errors.added
          end
        end

        def test_valid_turnstile_on_failure
          code = ErrorCode::INVALID_INPUT_RESPONSE
          fake = VerificationResponse.new({'success' => false, 'error-codes' => [code]})
          Verification.stub(:verify, fake) do
            @params[Cloudflare::RESPONSE_FIELD_NAME] = 'tok'

            refute valid_turnstile?(model: @model)
          end
        end

        def test_verify_turnstile_passes_options_to_verify # rubocop:disable Metrics/MethodLength
          captured = {}
          fake = VerificationResponse.new({ 'success' => true })

          Verification.stub(:verify, lambda { |**opts|
            captured.merge!(opts)
            fake
          }) do
            @params[Cloudflare::RESPONSE_FIELD_NAME] = 'tok'
            verify_turnstile(
              model: @model, secret: 'sk', response: 'explicit', remoteip: '1.2.3.4', idempotency_key: 'my-key'
            )

            assert_equal 'sk', captured[:secret]
            assert_equal 'explicit', captured[:response]
            assert_equal '1.2.3.4', captured[:remoteip]
            assert_equal 'my-key', captured[:idempotency_key]
          end
        end

        def test_turnstile_valid_alias_success
          fake = VerificationResponse.new({ 'success' => true })
          Verification.stub(:verify, fake) do
            @params[Cloudflare::RESPONSE_FIELD_NAME] = 'tok'

            assert valid_turnstile?(model: @model)
            assert turnstile_valid?(model: @model)
          end
        end

        def test_turnstile_valid_alias_failure
          fake = VerificationResponse.new(
            {'success' => false,
             'error-codes' => [ErrorCode::INVALID_INPUT_RESPONSE]}
          )
          Verification.stub(:verify, fake) do
            @params[Cloudflare::RESPONSE_FIELD_NAME] = 'tok'

            refute valid_turnstile?(model: @model)
            refute turnstile_valid?(model: @model)
          end
        end

        def test_alias_points_to_same_implementation
          m1 = method(:valid_turnstile?)
          m2 = method(:turnstile_valid?)

          assert_equal m1.owner, m2.owner
          assert_equal m1.source_location, m2.source_location
        end
      end
    end
  end
end
