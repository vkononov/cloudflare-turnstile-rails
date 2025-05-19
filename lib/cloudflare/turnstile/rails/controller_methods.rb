require_relative 'constants/error_message'
require_relative 'verification'

module Cloudflare
  module Turnstile
    module Rails
      module ControllerMethods
        def verify_turnstile(model: nil, response: nil, **opts)
          response ||= params[Cloudflare::RESPONSE_FIELD_NAME]
          result = Rails::Verification.verify(response: response, **opts)

          unless result.success?
            code = result.errors.first
            message = ErrorMessage.for(code)
            model&.errors&.add(:base, message)
          end

          result
        end

        def valid_turnstile?(model: nil, **opts)
          response = verify_turnstile(model: model, **opts)
          response.is_a?(VerificationResponse) && response.success?
        end

        alias turnstile_valid? valid_turnstile?
      end
    end
  end
end
