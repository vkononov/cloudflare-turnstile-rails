require_relative 'error_code'

module Cloudflare
  module Turnstile
    module Rails
      module ErrorMessage
        # I18n namespace for all error message translations
        SCOPE = 'cloudflare_turnstile.errors'.freeze

        # Fallback message used when no translation exists for an error code.
        # This can happen if Cloudflare introduces a new error code that we
        # haven't added to our locale files yet. The 'translate' method tries
        # the current locale first, then English, and finally falls back here.
        FALLBACK = "We could not verify that you're human. Please try again.".freeze

        def self.for(code)
          "#{translate(key_for(code))} (#{code})"
        end

        def self.default
          translate(:default)
        end

        # Backwards compatibility: ErrorMessage::DEFAULT still works (deprecated)
        def self.const_missing(name)
          if name == :DEFAULT
            warn '[DEPRECATION] ErrorMessage::DEFAULT is deprecated. Use ErrorMessage.default instead.'
            return default
          end

          super
        end

        # Converts Cloudflare error codes to i18n keys
        # e.g., 'timeout-or-duplicate' → :timeout_or_duplicate
        private_class_method def self.key_for(code)
          return :default if code.nil? || code.to_s.empty?

          code.to_s.tr('-', '_').to_sym
        end

        private_class_method def self.translate(key)
          I18n.t(key, scope: SCOPE, default: nil) ||
            I18n.t(key, scope: SCOPE, locale: :en, default: FALLBACK)
        end
      end
    end
  end
end
