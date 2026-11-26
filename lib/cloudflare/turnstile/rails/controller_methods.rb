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

        # flash: :keep carries the automatic failure message into the next request,
        # for a redirect. flash: :now scopes it to the response being rendered. The
        # keyword shadows the controller's own flash method, hence request.flash.
        def valid_turnstile?(model: nil, flash: :keep, **opts)
          response = verify_turnstile(model: model, **opts)
          success = response.is_a?(VerificationResponse) && response.success?

          if !success && model.nil?
            store = flash == :now ? request.flash.now : request.flash
            store[:alert] = ErrorMessage.default
          end

          success
        end

        alias turnstile_valid? valid_turnstile?
      end
    end
  end
end
