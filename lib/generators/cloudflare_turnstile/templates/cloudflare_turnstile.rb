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
end
