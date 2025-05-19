require 'test_helper'

require 'cloudflare/turnstile/rails/constants/error_code'
require 'cloudflare/turnstile/rails/constants/error_message'

module Cloudflare
  module Turnstile
    module Rails
      class ErrorMessageTest < Minitest::Test
        def setup
          @map = ErrorMessage::MAP
          @default = ErrorMessage::DEFAULT
        end

        def test_map_keys_match_error_codes_all
          # Ensure every code in ErrorCode::ALL is present as a key
          ErrorCode::ALL.each do |code|
            assert_includes @map.keys, code,
                            "Expected MAP to include key #{code.inspect}"
          end

          # No extra keys beyond ErrorCode::ALL
          extra = @map.keys - ErrorCode::ALL

          assert_empty extra, "Unexpected extra keys in MAP: #{extra.inspect}"
        end

        def test_map_values_are_strings_and_frozen
          @map.each do |code, message|
            assert_instance_of String, message,
                               "MAP[#{code.inspect}] should be String"
            assert_predicate message, :frozen?,
                             "MAP[#{code.inspect}] message should be frozen"
            refute_empty message,
                         "MAP[#{code.inspect}] message should not be empty"
          end
        end

        def test_default_is_string_and_frozen
          assert_instance_of String, @default
          assert_predicate @default, :frozen?, 'DEFAULT should be frozen'
          refute_empty @default, 'DEFAULT should not be empty'
        end

        def test_for_known_codes_appends_code
          ErrorCode::ALL.each do |code|
            base = @map[code]
            expected = "#{base} (#{code})"

            assert_equal expected,
                         ErrorMessage.for(code),
                         "ErrorMessage.for(#{code.inspect}) should append the code"
          end
        end

        def test_for_unknown_code_uses_default_and_appends_code
          unknown = 'some-unknown-code'
          expected = "#{@default} (#{unknown})"

          assert_equal expected,
                       ErrorMessage.for(unknown),
                       'ErrorMessage.for unknown code should use DEFAULT'
        end

        def test_for_nil_code_uses_default_and_appends_nil
          expected = "#{@default} ()"

          assert_equal expected,
                       ErrorMessage.for(nil),
                       "ErrorMessage.for(nil) should append '(nil)'"
        end
      end
    end
  end
end
