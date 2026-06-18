Cloudflare::Turnstile::Rails.configure do |config|
  # Set your Cloudflare Turnstile Site Key and Secret Key.
  config.site_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', nil)
  config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', nil)

  # Optional: Customize the script_url to point to a specific Cloudflare Turnstile script URL.
  # By default, the gem uses the standard Cloudflare Turnstile API script.
  # You can override this if you need a custom version of the script or want to add query parameters.
  # config.script_url = "https://challenges.cloudflare.com/turnstile/v0/api.js"

  # Optional: The render and onload parameters are used to control the behavior of the Turnstile widget.
  # - `render`: Controls the rendering mode of Turnstile. Defaults to 'explicit' so the gem can lazy-mount
  #             widgets without racing Cloudflare's auto-render observer. Set to 'auto' if you want
  #             Cloudflare to auto-render every widget the moment api.js arrives (this also disables
  #             lazy mounting; see `lazy_mount` below).
  # - `onload`: Defines a callback function name to be called when Turnstile script loads.
  # If you specify `render` or `onload`, the parameters will be appended to the default `script_url`.
  # If `script_url` is provided, it will be used directly and render/onload options will be ignored.
  # config.render = 'explicit'
  # config.onload = 'onloadTurnstileCallback'

  # Optional: Lazy-mount the Turnstile widget instead of rendering it immediately.
  #
  # When `lazy_mount` is true (the default), the gem defers loading Cloudflare's api.js and rendering
  # the widget until one of the following triggers fires:
  #   * the widget scrolls into view (IntersectionObserver),
  #   * the user touches, clicks, or types anywhere on the page,
  #   * the host app calls `cfTurnstile.mount(el)` or `cfTurnstile.mountAll()` from JavaScript.
  #
  # This avoids unnecessary network requests and improves initial page-load performance, especially
  # for forms below the fold or in hidden modals.
  #
  # Set this to false ONLY if you were on v1.x and you call `turnstile.render()` manually (i.e. you
  # had `config.render = 'explicit'` in v1). In that case, leave `config.render = 'explicit'` and
  # disable lazy mounting so that api.js loads eagerly the way it did before.
  #
  # Note: setting `config.lazy_mount = true` together with `config.render = 'auto'` is a
  # contradiction (Cloudflare auto-renders every widget on its own, leaving lazy triggers no work
  # to do). The gem will warn about this combination and behave as if lazy_mount were false.
  # config.lazy_mount = true

  # In the Rails Test environment, automatically fill in a dummy response if none was provided.
  # This lets you keep existing controller tests without having to add
  # params["cf-turnstile-response"] manually in every test.
  # config.auto_populate_response_in_test_env = true
end
