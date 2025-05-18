require_relative 'error_code'

module Cloudflare
  module Turnstile
    module Rails
      module ErrorMessage
        MAP = {
          ErrorCode::TIMEOUT_OR_DUPLICATE => 'Turnstile token has already been used or expired.'.freeze,
          ErrorCode::INVALID_INPUT_RESPONSE => 'Turnstile response parameter is invalid.'.freeze,
          ErrorCode::MISSING_INPUT_RESPONSE => 'Turnstile response parameter was not passed.'.freeze,
          ErrorCode::BAD_REQUEST => 'Turnstile request was rejected because it was malformed.'.freeze,
          ErrorCode::INTERNAL_ERROR => 'Turnstile Internal error occurred while validating the response. Please try again.'.freeze,
          ErrorCode::MISSING_INPUT_SECRET => 'Turnstile secret key missing.'.freeze,
          ErrorCode::INVALID_INPUT_SECRET => 'Turnstile secret parameter was invalid, did not exist, or is a testing secret key with a non-testing response.'.freeze
        }.freeze

        DEFAULT = "We could not verify that you're human. Please try again.".freeze

        def self.for(code)
          base = MAP.fetch(code, DEFAULT)
          "#{base} (#{code})"
        end
      end
    end
  end
end
