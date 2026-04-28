require 'application_system_test_case'

class LazyMountTest < ApplicationSystemTestCase
  setup do
    Cloudflare::Turnstile::Rails.configure do |config|
      config.site_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', '1x00000000000000000000AA')
      config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', '1x0000000000000000000000000000000AA')
    end
  end

  test 'widget below the fold is not rendered until forced' do
    visit lazy_demo_url

    # The placeholder div exists right away.
    assert_selector 'div.cf-turnstile', visible: :all, count: 1

    # But Cloudflare hasn't rendered into it yet (no hidden input).
    assert_no_selector "div.cf-turnstile input[name='cf-turnstile-response']", visible: :all, wait: 1

    # Force-mount via the public JS API and confirm the widget actually renders.
    mount_turnstile_widgets!
    wait_for_turnstile_inputs(1)
  end

  test 'cfTurnstile public API is exposed on window' do
    visit lazy_demo_url

    api_shape = evaluate_script(<<~JS)
      (function() {
        if (typeof window.cfTurnstile !== 'object' || window.cfTurnstile === null) { return null; }
        return {
          ensureLoaded: typeof window.cfTurnstile.ensureLoaded,
          mount: typeof window.cfTurnstile.mount,
          mountAll: typeof window.cfTurnstile.mountAll
        };
      })()
    JS

    assert_equal({ 'ensureLoaded' => 'function', 'mount' => 'function', 'mountAll' => 'function' }, api_shape)
  end

  test 'first-gesture trigger mounts pending widgets' do
    visit lazy_demo_url

    assert_no_selector "div.cf-turnstile input[name='cf-turnstile-response']", visible: :all, wait: 1

    # A click anywhere on the page should fire the gesture trigger.
    find('#spacer').click
    wait_for_turnstile_inputs(1, message: 'after first-gesture click')
  end
end
