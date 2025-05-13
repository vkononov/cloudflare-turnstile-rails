require_relative 'constants/cloudflare'
require_relative 'constants/error_messages'
require_relative 'verification'

module Cloudflare
  module Turnstile
    module Rails
      module ControllerMethods
        def verify_turnstile(model: nil, secret: nil, response: nil, remoteip: nil, idempotency_key: nil) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
          response ||= params[Cloudflare::RESPONSE_FIELD_NAME]

          if response.nil? || response.strip.empty?
            error_message = ErrorMessages::MISSING_TOKEN_MESSAGE
            model&.errors&.add(:base, error_message)
            return false
          end

          result = Rails::Verification.verify(
            secret: secret,
            response: response,
            remoteip: remoteip,
            idempotency_key: idempotency_key
          )

          unless result.success?
            error_code = result.errors.first
            error_message = ErrorMessages::MAP.fetch(error_code, ErrorMessages::DEFAULT_MESSAGE)
            model&.errors&.add(:base, error_message)
            return false
          end

          result
        end
      end
    end
  end
end
