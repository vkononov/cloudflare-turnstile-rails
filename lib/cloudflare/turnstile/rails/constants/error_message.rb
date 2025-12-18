require_relative 'error_code'

module Cloudflare
  module Turnstile
    module Rails
      module ErrorMessage
        # I18n namespace for all error message translations
        SCOPE = 'cloudflare_turnstile.errors'.freeze

        # Fallback message used when no translation exists for an error code.
        # This can happen if Cloudflare introduces a new error code that we
        # haven't added to our locale files yet. Rails I18n fallbacks are
        # respected if configured (config.i18n.fallbacks = true).
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

        # Looks up translation for the given key in the current locale.
        #
        # Fallback behavior depends on the app's Rails configuration:
        # - With `config.i18n.fallbacks = true`: tries current locale, then
        #   fallback chain (e.g., :pt → :sp), then FALLBACK constant
        # - Without fallbacks (default): tries current locale, then FALLBACK
        private_class_method def self.translate(key)
          I18n.t(key, scope: SCOPE, default: FALLBACK)
        end
      end
    end
  end
end
