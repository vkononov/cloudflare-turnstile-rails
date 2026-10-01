require 'test_helper'

require 'webmock/minitest'

require 'cloudflare/turnstile/rails/constants/cloudflare'
require 'cloudflare/turnstile/rails/constants/error_code'
require 'cloudflare/turnstile/rails/constants/error_message'
require 'cloudflare/turnstile/rails/verification'

module Cloudflare
  module Turnstile
    module Rails
      class VerificationResponseTest < Minitest::Test
        def setup
          @raw = {
            'success' => true,
            'error-codes' => %w[foo bar],
            'action' => 'test_action',
            'cdata' => 'custom-data',
            'challenge_ts' => '2022-10-06T00:07:23.274Z',
            'hostname' => 'example.com',
            'metadata' => { 'ephemeral_id' => 'x:123' }
          }
          @resp = VerificationResponse.new(@raw)
        end

        def test_success?
          assert_predicate @resp, :success?
        end

        def test_errors
          assert_equal %w[foo bar], @resp.errors
        end

        def test_action_cdata_ts_hostname_metadata
          assert_equal 'test_action', @resp.action
          assert_equal 'custom-data', @resp.cdata
          assert_equal '2022-10-06T00:07:23.274Z', @resp.challenge_ts
          assert_equal 'example.com', @resp.hostname
          assert_equal({ 'ephemeral_id' => 'x:123' }, @resp.metadata)
        end

        def test_to_h_returns_raw
          assert_same @raw, @resp.to_h
        end

        def test_errors_empty_when_none
          empty = VerificationResponse.new({})

          assert_empty empty.errors
        end
      end

      module VerificationTestHelpers
        def setup
          @url = Cloudflare::SITE_VERIFY_URL
          @valid_secret = 'sk_test'
          @valid_token = 'tok_test'

          Rails.configure do |c|
            c.secret_key = @valid_secret
          end
        end

        def stub_verify(opts = {})
          status = opts.delete(:status) || 200

          stub_request(:post, @url)
            .with(headers: { 'Content-Type' => 'application/x-www-form-urlencoded' })
            .to_return(
              status: status,
              body: opts.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        # Stubs siteverify so it only matches when the posted form includes the given fields.
        def stub_verify_with_body(expected, response)
          stub_request(:post, @url)
            .with { |req| expected <= URI.decode_www_form(req.body).to_h }
            .to_return(body: response.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        def with_rails_env(env)
          original = ::Rails.env
          ::Rails.env = env
          yield
        ensure
          ::Rails.env = original
        end
      end

      class VerificationTest < Minitest::Test
        include VerificationTestHelpers

        def test_missing_response_proceeds_and_returns_verification_response
          stub_verify('success' => true, 'error-codes' => [])
          resp = Verification.verify(response: '')

          assert_kind_of VerificationResponse, resp
          assert_predicate resp, :success?
          assert_empty resp.errors
        end

        def test_missing_secret_raises
          Rails.configuration.secret_key = nil
          expected = ErrorMessage.for(ErrorCode::MISSING_INPUT_SECRET)

          err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
          assert_equal expected, err.message
        end

        def test_successful_verification
          stub_verify('success' => true)
          resp = Verification.verify(response: @valid_token)

          assert_kind_of VerificationResponse, resp
          assert_predicate resp, :success?
          assert_empty resp.errors
        end

        def test_verification_with_error_codes
          stub_verify('success' => false, 'error-codes' => ['timeout-or-duplicate'])
          resp = Verification.verify(response: @valid_token)

          refute_predicate resp, :success?
          assert_equal ['timeout-or-duplicate'], resp.errors
        end

        def test_remoteip_and_idempotency_key_submitted
          uuid = SecureRandom.uuid
          expected = { 'remoteip' => '1.2.3.4', 'idempotency_key' => uuid, 'secret' => @valid_secret,
                       'response' => @valid_token }
          stub_verify_with_body(expected, { 'success' => true })

          resp = Verification.verify(response: @valid_token, remoteip: '1.2.3.4', idempotency_key: uuid)

          assert_predicate resp, :success?
        end

        def test_json_parse_error_raises
          stub_request(:post, @url).to_return(body: 'not json', headers: { 'Content-Type' => 'application/json' })

          expected = ErrorMessage.for(ErrorCode::INTERNAL_ERROR)
          err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
          assert_equal expected, err.message
        end

        def test_timeout_raises_configuration_error
          stub_request(:post, @url).to_timeout

          err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
          assert_match(/timed out/, err.message)
        end

        def test_ssl_error_raises_configuration_error
          stub_request(:post, @url).to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed'))

          err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
          assert_match(/SSL verification failed/, err.message)
        end

        def test_socket_error_raises_configuration_error
          stub_request(:post, @url).to_raise(SocketError.new('getaddrinfo: Name or service not known'))

          err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
          assert_match(/Network error/, err.message)
        end

        def test_connection_refused_raises_configuration_error
          stub_request(:post, @url).to_raise(Errno::ECONNREFUSED.new('Connection refused'))

          err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
          assert_match(/Network error/, err.message)
        end

        def test_non_success_http_status_with_json_body_is_returned
          stub_verify('success' => false, 'error-codes' => ['internal-error'], status: 500)
          resp = Verification.verify(response: @valid_token)

          refute_predicate resp, :success?
          assert_equal ['internal-error'], resp.errors
        end
      end

      # Inputs that are blank or only whitespace: tokens, secrets, and the
      # test-environment token substitution.
      class VerificationBlankInputTest < Minitest::Test
        include VerificationTestHelpers

        MISSING_RESPONSE = { 'success' => false, 'error-codes' => ['missing-input-response'] }.freeze

        def teardown
          Rails.configuration.auto_populate_response_in_test_env = true
        end

        def test_whitespace_token_is_sent_as_is_when_auto_populate_is_off
          with_rails_env('test') do
            Rails.configuration.auto_populate_response_in_test_env = false
            stub_verify_with_body({ 'response' => '  ' }, MISSING_RESPONSE)

            resp = Verification.verify(response: '  ')

            refute_predicate resp, :success?
            assert_equal ['missing-input-response'], resp.errors
          end
        end

        def test_blank_token_is_replaced_in_the_test_environment
          with_rails_env('test') do
            stub_verify_with_body({ 'response' => 'dummy-response' }, { 'success' => true })

            assert_predicate Verification.verify(response: nil), :success?
          end
        end

        def test_whitespace_token_is_replaced_in_the_test_environment
          with_rails_env('test') do
            stub_verify_with_body({ 'response' => 'dummy-response' }, { 'success' => true })

            assert_predicate Verification.verify(response: "\t "), :success?
          end
        end

        def test_blank_token_is_not_replaced_outside_the_test_environment
          with_rails_env('production') do
            stub_verify_with_body({ 'response' => '' }, MISSING_RESPONSE)

            refute_predicate Verification.verify(response: nil), :success?
          end
        end

        def test_whitespace_only_secret_raises
          Rails.configuration.secret_key = "  \n"
          expected = ErrorMessage.for(ErrorCode::MISSING_INPUT_SECRET)

          err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
          assert_equal expected, err.message
        end

        def test_explicit_secret_overrides_the_configured_one
          Rails.configuration.secret_key = nil
          stub_verify_with_body({ 'secret' => 'explicit' }, { 'success' => true })

          assert_predicate Verification.verify(response: @valid_token, secret: 'explicit'), :success?
        end

        def test_whitespace_explicit_secret_raises
          err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token, secret: ' ') }
          assert_equal ErrorMessage.for(ErrorCode::MISSING_INPUT_SECRET), err.message
        end
      end
    end
  end
end
