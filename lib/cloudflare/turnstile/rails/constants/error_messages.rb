require_relative 'error_codes'

module Cloudflare
  module Turnstile
    module Rails
      module ErrorMessages
        MAP = {
          ErrorCodes::TIMEOUT_OR_DUPLICATE => 'Turnstile token has already been used or expired.',
          ErrorCodes::INVALID_INPUT_RESPONSE => 'Turnstile token is invalid.',
          ErrorCodes::MISSING_INPUT_RESPONSE => 'Turnstile response was missing.',
          ErrorCodes::BAD_REQUEST => 'Bad request to Turnstile verification API.',
          ErrorCodes::INTERNAL_ERROR => 'Internal error at Turnstile. Please try again.',
          ErrorCodes::MISSING_INPUT_SECRET => 'Server misconfiguration: Turnstile secret key missing.',
          ErrorCodes::INVALID_INPUT_SECRET => 'Server misconfiguration: Turnstile secret key invalid.'
        }.freeze

        DEFAULT_MESSAGE = "We could verify that you're human. Please try again.".freeze
        MISSING_TOKEN_MESSAGE = 'Cloudflare Turnstile verification missing.'.freeze
      end
    end
  end
end
