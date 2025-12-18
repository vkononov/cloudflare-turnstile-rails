require 'test_helper'

require 'cloudflare/turnstile/rails/constants/error_code'
require 'cloudflare/turnstile/rails/constants/error_message'

module Cloudflare
  module Turnstile
    module Rails
      class ErrorMessageTest < Minitest::Test
        def test_scope_is_correct
          assert_equal 'cloudflare_turnstile.errors', ErrorMessage::SCOPE
        end

        def test_fallback_is_frozen
          assert_predicate ErrorMessage::FALLBACK, :frozen?
        end

        def test_default_returns_string
          result = ErrorMessage.default

          assert_instance_of String, result
          refute_empty result
        end

        def test_for_known_codes_returns_message_with_code
          ErrorCode::ALL.each do |code|
            result = ErrorMessage.for(code)

            assert_instance_of String, result, "ErrorMessage.for(#{code.inspect}) should return String"
            assert result.end_with?("(#{code})"), "ErrorMessage.for(#{code.inspect}) should end with (#{code})"
            refute_empty result
          end
        end

        def test_for_unknown_code_uses_default_and_appends_code
          unknown = 'some-unknown-code'
          expected = "#{ErrorMessage.default} (#{unknown})"

          assert_equal expected, ErrorMessage.for(unknown)
        end

        def test_for_nil_code_uses_default
          result = ErrorMessage.for(nil)

          assert_equal "#{ErrorMessage.default} ()", result
        end

        def test_for_empty_string_code_uses_default
          result = ErrorMessage.for('')

          assert_equal "#{ErrorMessage.default} ()", result
        end

        def test_backwards_compat_default_constant_with_deprecation_warning
          # ErrorMessage::DEFAULT should still work via const_missing but emit a warning
          result = nil
          stderr = capture_stderr do
            result = ErrorMessage::DEFAULT
          end

          assert_instance_of String, result
          assert_equal ErrorMessage.default, result
          assert_match(/\[DEPRECATION\]/, stderr)
          assert_match(/ErrorMessage\.default/, stderr)
        end

        private

        def capture_stderr
          original = $stderr
          $stderr = StringIO.new
          yield
          $stderr.string
        ensure
          $stderr = original
        end
      end
    end
  end
end
