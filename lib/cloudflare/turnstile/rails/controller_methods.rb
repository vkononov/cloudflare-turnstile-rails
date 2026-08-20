require_relative 'constants/error_message'
require_relative 'verification'

module Cloudflare
  module Turnstile
    module Rails
      module ControllerMethods
        def verify_turnstile(model: nil, **opts)
          response ||= params[Cloudflare::RESPONSE_FIELD_NAME]
          result = Rails::Verification.verify(response: response, **opts)

          unless result.success?
            message = ErrorMessage.default
            model&.errors&.add(:base, message)
          end

          result
        end

        def valid_turnstile?(model: nil, flash: true, **opts)
          response = verify_turnstile(model: model, **opts)
          success = response.is_a?(VerificationResponse) && response.success?
          add_turnstile_flash_alert(flash) if !success && model.nil?
          success
        end

        alias turnstile_valid? valid_turnstile?

        private

        # true keeps the alert for the next request, :now limits it to the
        # current render, false leaves the flash alone.
        def add_turnstile_flash_alert(mode)
          return unless mode

          store = mode == :now ? flash.now : flash
          store[:alert] = ErrorMessage.default
        end
      end
    end
  end
end
