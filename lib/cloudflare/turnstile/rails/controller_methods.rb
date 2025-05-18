require_relative 'constants/error_message'
require_relative 'verification'

module Cloudflare
  module Turnstile
    module Rails
      module ControllerMethods
        def verify_turnstile(model: nil, secret: nil, response: nil, remoteip: nil, idempotency_key: nil) # rubocop:disable Metrics/MethodLength
          response ||= params[Cloudflare::RESPONSE_FIELD_NAME]

          begin
            result = Rails::Verification.verify(
              secret: secret,
              response: response,
              remoteip: remoteip,
              idempotency_key: idempotency_key
            )
          rescue ConfigurationError => e
            model&.errors&.add(:base, e.message)
            return false
          end

          unless result.success?
            code = result.errors.first
            message = ErrorMessage.for(code)
            model&.errors&.add(:base, message)
            return false
          end

          result
        end
      end
    end
  end
end
