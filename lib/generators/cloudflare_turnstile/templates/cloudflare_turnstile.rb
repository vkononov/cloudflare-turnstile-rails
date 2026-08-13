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
  #   * the widget scrolls into (or near) view (IntersectionObserver),
  #   * the user focuses or hovers a field in the same <form> as the widget,
  #   * the widget is revealed (a <dialog> opens, a <details> expands, a popover shows, or a
  #     `display: none` ancestor becomes visible),
  #   * the user touches, clicks, or types anywhere on the page,
  #   * the host app calls `cfTurnstile.mount(el)` or `cfTurnstile.mountAll()` from JavaScript.
  #
  # This avoids unnecessary network requests and improves initial page-load performance, especially
  # for forms below the fold or in hidden modals.
  #
  # Set this to false to get the v1.x behaviour: the gem still renders your widgets, but loads api.js
  # at boot and renders every widget as soon as it can. Do NOT use this if you render widgets
  # yourself — see `manual_render` below.
  #
  # Note: lazy mounting only works if the api.js URL carries `render=explicit`. If you set
  # `config.render = 'auto'`, or a custom `config.script_url` without that parameter, Cloudflare
  # auto-renders every widget on its own and there is nothing left to defer. The gem warns about
  # that on boot and falls back to eager mounting.
  # config.lazy_mount = true

  # Optional: Let your own JavaScript render the widgets.
  #
  # When `manual_render` is true, the gem injects api.js (honouring your CSP nonce) and exposes
  # `cfTurnstile.ensureLoaded(cb)`, but never renders, observes, or re-renders anything — you call
  # `turnstile.render(...)` yourself. This takes precedence over `lazy_mount`.
  #
  # This is the setting to use if you were on v1.x with `config.render = 'explicit'` and your own
  # render calls.
  # config.manual_render = false

  # Optional: Reserve vertical space for the widget to prevent Cumulative Layout Shift.
  #
  # In lazy mode the widget's box doesn't exist until it mounts, so the page would jump when the
  # iframe swaps in. The gem reserves a matching `min-height` (65px, or 120px for `size: 'compact'`)
  # from JavaScript and releases it once the widget renders. It never overrides a `min-height` you
  # set yourself, and applies only in lazy mode.
  #
  # Turn this off if your sitekey is configured as invisible or managed-without-UI in the Cloudflare
  # dashboard, since such a widget occupies no space. You can also override it per tag with
  # `cloudflare_turnstile_tag reserve_space: false`.
  # config.reserve_space = true

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
