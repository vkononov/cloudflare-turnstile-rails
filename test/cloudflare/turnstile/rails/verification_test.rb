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

        def assert_rejected_without_calling_cloudflare(
          response,
          error: ErrorCode::INVALID_INPUT_RESPONSE,
          env: 'production'
        )
          with_rails_env(env) do
            resp = Verification.verify(response: response)

            refute_predicate resp, :success?
            assert_equal [error], resp.errors
            assert_not_requested :post, @url
          end
        end
      end

      class VerificationTest < Minitest::Test
        include VerificationTestHelpers

        def test_missing_response_fails_without_calling_cloudflare
          assert_rejected_without_calling_cloudflare('', error: ErrorCode::MISSING_INPUT_RESPONSE)
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

        def test_ssl_error_raises_configuration_error
          stub_request(:post, @url).to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed'))

          err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
          assert_match(/SSL verification failed/, err.message)
        end

        # Each exception below is one Verification rescues and reports as a timeout.
        TIMEOUT_ERRORS = {
          'timeout' => Net::OpenTimeout.new('execution expired'),
          'read_timeout' => Net::ReadTimeout.new('read timeout'),
          'write_timeout' => Net::WriteTimeout.new('write timeout'),
          'connection_timed_out' => Errno::ETIMEDOUT.new('Connection timed out')
        }.freeze

        # Each exception below is one Verification rescues and reports as a network error.
        NETWORK_ERRORS = {
          'socket_error' => SocketError.new('getaddrinfo: Name or service not known'),
          'eof_error' => EOFError.new('end of file reached'),
          'connection_refused' => Errno::ECONNREFUSED.new('Connection refused'),
          'connection_reset' => Errno::ECONNRESET.new('Connection reset by peer'),
          'host_unreachable' => Errno::EHOSTUNREACH.new('No route to host')
        }.freeze

        TIMEOUT_ERRORS.each do |name, exception|
          define_method("test_#{name}_raises_configuration_error") do
            stub_request(:post, @url).to_raise(exception)

            err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
            assert_match(/timed out/, err.message)
          end
        end

        NETWORK_ERRORS.each do |name, exception|
          define_method("test_#{name}_raises_configuration_error") do
            stub_request(:post, @url).to_raise(exception)

            err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
            assert_match(/Network error/, err.message)
          end
        end

        def test_non_success_http_status_with_json_body_is_returned
          stub_verify('success' => false, 'error-codes' => ['internal-error'], status: 500)
          resp = Verification.verify(response: @valid_token)

          refute_predicate resp, :success?
          assert_equal ['internal-error'], resp.errors
        end
      end

      # Tokens Cloudflare would reject are failed locally, without a request.
      class VerificationMalformedInputTest < Minitest::Test
        include VerificationTestHelpers

        def test_overlong_token_is_rejected
          assert_rejected_without_calling_cloudflare('a' * (Cloudflare::MAX_RESPONSE_LENGTH + 1))
        end

        def test_token_at_the_length_limit_is_sent
          token = 'a' * Cloudflare::MAX_RESPONSE_LENGTH
          stub_verify_with_body({ 'response' => token }, { 'success' => true })

          assert_predicate Verification.verify(response: token), :success?
        end

        NON_STRING_BLANK_VALUES = {
          'false' => false,
          'empty_array' => [],
          'empty_hash' => {},
          'empty_parameters' => ActionController::Parameters.new
        }.freeze

        NON_STRING_BLANK_VALUES.each do |name, value|
          define_method("test_#{name}_token_is_rejected") do
            assert_rejected_without_calling_cloudflare(value)
          end

          define_method("test_#{name}_token_is_rejected_in_test_env_with_auto_populate_on") do
            assert_rejected_without_calling_cloudflare(value, env: 'test')
          end
        end
      end

      # Proves that a Rails.configuration timeout reaches the real Net::HTTP
      # instance, rather than only being stored on Configuration. http.use_ssl
      # is always true in verify, so even a plaintext loopback server that
      # never responds stalls Net::HTTP in the TLS handshake, which Ruby times
      # with open_timeout rather than read_timeout. read_timeout and
      # write_timeout are assigned the same way, immediately before/after this
      # line, but aren't independently exercised here: reaching them would
      # require a loopback server that completes a real TLS handshake.
      class VerificationSocketTimeoutTest < Minitest::Test
        include VerificationTestHelpers

        def teardown
          super
          Rails.configuration.open_timeout = 5
        end

        def test_configured_open_timeout_is_enforced_by_net_http
          Rails.configuration.open_timeout = 0.2

          with_unresponsive_server do
            started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            err = assert_raises(ConfigurationError) { Verification.verify(response: @valid_token) }
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

            assert_match(/timed out/, err.message)
            assert_operator elapsed, :<, 2
          end
        end

        private

        # Points SITE_VERIFY_URL at a real TCP server that accepts connections
        # and never writes a response, then restores the original constant.
        # WebMock blocks real connections by default, so localhost is allowed
        # only for the duration of the request.
        def with_unresponsive_server
          server = TCPServer.new('127.0.0.1', 0)
          accept_thread = Thread.new { loop { server.accept } }

          swap_site_verify_url("http://127.0.0.1:#{server.addr[1]}/siteverify") do
            WebMock.disable_net_connect!(allow_localhost: true)
            yield
          end
        ensure
          WebMock.disable_net_connect!
          accept_thread&.kill
          server&.close
        end

        def swap_site_verify_url(url)
          original = Cloudflare::SITE_VERIFY_URL
          Cloudflare.send(:remove_const, :SITE_VERIFY_URL)
          Cloudflare.const_set(:SITE_VERIFY_URL, url)
          yield
        ensure
          Cloudflare.send(:remove_const, :SITE_VERIFY_URL)
          Cloudflare.const_set(:SITE_VERIFY_URL, original)
        end
      end

      # Inputs that are blank or only whitespace: tokens, secrets, and the
      # test-environment token substitution.
      class VerificationBlankInputTest < Minitest::Test
        include VerificationTestHelpers

        def teardown
          super
          Rails.configuration.auto_populate_response_in_test_env = true
        end

        def test_whitespace_token_fails_without_calling_cloudflare
          assert_rejected_without_calling_cloudflare('   ')
        end

        def test_whitespace_token_fails_locally_when_auto_populate_is_off
          Rails.configuration.auto_populate_response_in_test_env = false

          assert_rejected_without_calling_cloudflare('  ', error: ErrorCode::INVALID_INPUT_RESPONSE, env: 'test')
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
          assert_rejected_without_calling_cloudflare(nil, error: ErrorCode::MISSING_INPUT_RESPONSE)
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
