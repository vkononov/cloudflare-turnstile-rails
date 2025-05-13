module Cloudflare
  module Turnstile
    module Rails
      module Cloudflare
        # Client-side script for rendering Turnstile widgets
        SCRIPT_URL = 'https://challenges.cloudflare.com/turnstile/v0/api.js'.freeze

        # Server-side endpoint for verifying Turnstile tokens
        SITE_VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify'.freeze

        # Default hidden input field name for Turnstile token submission
        RESPONSE_FIELD_NAME = 'cf-turnstile-response'.freeze

        # Default CSS class applied to Turnstile widget containers
        WIDGET_CLASS = 'cf-turnstile'.freeze
      end
    end
  end
end
