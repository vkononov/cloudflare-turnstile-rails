require 'test_helper'

require 'cloudflare/turnstile/rails/constants/error_code'

module Cloudflare
  module Turnstile
    module Rails
      class ErrorCodeTest < Minitest::Test
        CONSTANTS = {
          missing_input_secret: 'missing-input-secret',
          invalid_input_secret: 'invalid-input-secret',
          missing_input_response: 'missing-input-response',
          invalid_input_response: 'invalid-input-response',
          bad_request: 'bad-request',
          timeout_or_duplicate: 'timeout-or-duplicate',
          internal_error: 'internal-error'
        }.freeze

        def test_each_constant_defined_and_matches
          CONSTANTS.each do |sym, expected|
            const_name = sym.upcase

            assert ErrorCode.const_defined?(const_name), "Expected #{const_name} to be defined"
            value = ErrorCode.const_get(const_name)

            assert_equal expected, value, "#{const_name} should be #{expected.inspect}"
            assert_predicate value, :frozen?, "#{const_name} string should be frozen"
          end
        end

        def test_all_array
          # ALL must be defined, an Array, and frozen
          assert ErrorCode.const_defined?('ALL')
          all = ErrorCode::ALL

          assert_kind_of Array, all
          assert_equal CONSTANTS.values, all
          assert_predicate all, :frozen?, 'ErrorCode::ALL should be frozen'

          # ensure no duplicates and exact coverage
          assert_equal CONSTANTS.values.sort, all.uniq.sort
          assert_equal CONSTANTS.size, all.size
        end

        def test_all_array_immutable
          assert_raises(FrozenError) { ErrorCode::ALL << 'something' }
        end
      end
    end
  end
end
