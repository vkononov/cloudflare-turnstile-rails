Cloudflare::Turnstile::Rails.configure do |config|
  # Set your Cloudflare Turnstile Site Key and Secret Key.
  config.site_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', nil)
  config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', nil)

  # Optional: Customize the script_url to point to a specific Cloudflare Turnstile script URL.
  # By default, the gem uses the standard Cloudflare Turnstile API script.
  # You can override this if you need a custom version of the script or want to add query parameters.
  # config.script_url = "https://challenges.cloudflare.com/turnstile/v0/api.js"

  # Optional: The render and onload parameters are used to control the behavior of the Turnstile widget.
  # - `render`: Controls the rendering mode of Turnstile (default is 'auto').
  # - `onload`: Defines a callback function name to be called when Turnstile script loads.
  # If you specify `render` or `onload`, the parameters will be appended to the default `script_url`.
  # If `script_url` is provided, it will be used directly and render/onload options will be ignored.
  # config.render = 'explicit'
  # config.onload = 'onloadTurnstileCallback'

  # Optional: Default data-* attributes applied to every `cloudflare_turnstile_tag`.
  # These are merged into each widget and can be overridden per tag via the `data:` option.
  # See https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#configuration-options
  # Values may be a proc, evaluated at render time (e.g. to follow the current locale).
  # config.default_data = {
  #   theme: 'auto',
  #   language: -> { I18n.locale }
  # }

  # In the Rails Test environment, automatically fill in a dummy response if none was provided.
  # This lets you keep existing controller tests without having to add
  # params["cf-turnstile-response"] manually in every test.
  # config.auto_populate_response_in_test_env = true
end
