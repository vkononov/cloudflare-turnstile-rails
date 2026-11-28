require 'application_system_test_case'

class LazyMountTest < ApplicationSystemTestCase
  setup do
    # Restore the full default config — other test files mutate
    # `lazy_mount` and `render`, and configuration is process-wide.
    Cloudflare::Turnstile::Rails.configure do |config|
      config.site_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', '1x00000000000000000000AA')
      config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', '1x0000000000000000000000000000000AA')
      config.render = 'explicit'
      config.lazy_mount = true
      config.manual_render = false
      config.reserve_space = true
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

  test 'submitting the lazy form after the widget mounts validates server-side' do
    # Full round-trip: mount the widget, submit the form, verify that
    # the resulting Turnstile token reaches the server and the
    # PagesController#lazy_demo action accepts it.
    visit lazy_demo_url
    mount_turnstile_widgets!
    wait_for_turnstile_inputs(1)

    click_on 'Submit lazy form'

    assert_text 'Lazy demo verified.'
  end

  test 'cfTurnstile public API is exposed on window' do
    visit lazy_demo_url

    api_shape = evaluate_script(<<~JS)
      (function() {
        if (typeof window.cfTurnstile !== 'object' || window.cfTurnstile === null) { return null; }
        return {
          ensureLoaded: typeof window.cfTurnstile.ensureLoaded,
          mount: typeof window.cfTurnstile.mount,
          mountAll: typeof window.cfTurnstile.mountAll,
          mountMode: window.cfTurnstile.mountMode
        };
      })()
    JS

    assert_equal(
      { 'ensureLoaded' => 'function', 'mount' => 'function', 'mountAll' => 'function', 'mountMode' => 'lazy' },
      api_shape
    )
  end

  test 'first-gesture trigger mounts pending widgets' do
    visit lazy_demo_url

    assert_no_selector "div.cf-turnstile input[name='cf-turnstile-response']", visible: :all, wait: 1

    # A click anywhere on the page should fire the gesture trigger.
    find('#spacer').click
    wait_for_turnstile_inputs(1, message: 'after first-gesture click')
  end

  test 'focusing a field in the widget form mounts it before the user can submit' do
    visit lazy_demo_url

    assert_no_selector "div.cf-turnstile input[name='cf-turnstile-response']", visible: :all, wait: 1

    # Focus programmatically rather than clicking: a click would also fire the
    # first-gesture trigger, so the assertion below would pass even if the
    # form-interaction trigger were broken. `focus()` fires focusin only.
    execute_script("document.getElementById('lazy-demo-message').focus()")

    wait_for_turnstile_inputs(1, message: 'after focusing a field in the same form')
  end

  test 'the placeholder reserves height before the widget mounts, then releases it' do
    visit lazy_demo_url

    # The server-rendered markup carries the height as a data attribute only;
    # the helper writes it through the CSSOM, which CSP's style-src-attr does
    # not govern, so no 'unsafe-inline' relaxation is needed.
    assert_selector "div.cf-turnstile[data-reserve-height='65']", visible: :all
    assert_selector "div.cf-turnstile[style*='min-height: 65px']", visible: :all

    mount_turnstile_widgets!
    wait_for_turnstile_inputs(1)

    # Once the iframe supplies its own height the reservation is dropped, so a
    # space-less widget can't leave a permanent gap behind.
    assert_no_selector "div.cf-turnstile[style*='min-height']", visible: :all
  end
end
