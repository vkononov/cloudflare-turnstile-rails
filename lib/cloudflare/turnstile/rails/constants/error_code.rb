module Cloudflare
  module Turnstile
    module Rails
      module ErrorCode
        # https://developers.cloudflare.com/turnstile/get-started/server-side-validation/#error-codes

        MISSING_INPUT_SECRET = 'missing-input-secret'.freeze
        INVALID_INPUT_SECRET = 'invalid-input-secret'.freeze
        MISSING_INPUT_RESPONSE = 'missing-input-response'.freeze
        INVALID_INPUT_RESPONSE = 'invalid-input-response'.freeze
        BAD_REQUEST = 'bad-request'.freeze
        TIMEOUT_OR_DUPLICATE = 'timeout-or-duplicate'.freeze
        INTERNAL_ERROR = 'internal-error'.freeze

        ALL = [
          MISSING_INPUT_SECRET,
          INVALID_INPUT_SECRET,
          MISSING_INPUT_RESPONSE,
          INVALID_INPUT_RESPONSE,
          BAD_REQUEST,
          TIMEOUT_OR_DUPLICATE,
          INTERNAL_ERROR
        ].freeze
      end
    end
  end
end
