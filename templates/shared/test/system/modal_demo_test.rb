require 'application_system_test_case'

# End-to-end coverage for the "widget hidden in a closed modal" scenario.
# The point of lazy mounting is that we should NOT pay the network cost of
# Cloudflare's api.js until the user is actually about to see the widget.
# A widget tucked inside a `display: none` modal is precisely that case:
# the viewer might never open the modal, and even if they do interact with
# the page first (clicking around, typing) we still shouldn't render the
# widget — only opening the modal should.
class ModalDemoTest < ApplicationSystemTestCase
  setup do
    Cloudflare::Turnstile::Rails.configure do |config|
      config.site_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', '1x00000000000000000000AA')
      config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', '1x0000000000000000000000000000000AA')
    end
  end

  test 'widget inside a closed modal does not render until the modal is opened' do
    visit modal_demo_url

    # The placeholder div exists in the DOM (it was rendered by the helper).
    assert_selector 'div.cf-turnstile', visible: :all, count: 1

    # But Cloudflare hasn't rendered into it yet — no hidden response input.
    assert_no_selector "div.cf-turnstile input[name='cf-turnstile-response']", visible: :all, wait: 1

    # Click somewhere outside the modal. This fires the helper's first-
    # gesture trigger, which calls mountAllVisible(). Because the widget
    # lives inside a `display: none` ancestor, isLaidOut() returns false
    # for it and the gesture trigger skips it.
    find('#outside-modal-text').click

    assert_no_selector(
      "div.cf-turnstile input[name='cf-turnstile-response']",
      visible: :all, wait: 1
    )

    # Now open the modal. The widget becomes laid-out, IntersectionObserver
    # fires, and the helper mounts it for real.
    click_on 'Open modal'
    wait_for_turnstile_inputs(1, message: 'after opening modal')
  end

  test 'pressing keys (a non-modal-opening gesture) does not mount the hidden widget' do
    visit modal_demo_url

    assert_no_selector "div.cf-turnstile input[name='cf-turnstile-response']", visible: :all, wait: 1

    # Type a key on the document — fires the keydown gesture trigger.
    find('body').send_keys(:tab)

    assert_no_selector(
      "div.cf-turnstile input[name='cf-turnstile-response']",
      visible: :all, wait: 1
    )
  end

  test 'cfTurnstile.mountAll() force-mounts the modal-hidden widget anyway' do
    visit modal_demo_url

    assert_no_selector "div.cf-turnstile input[name='cf-turnstile-response']", visible: :all, wait: 1

    # The public API explicitly bypasses the visibility filter so consumers
    # can pre-warm a widget that's about to become visible.
    mount_turnstile_widgets!
    wait_for_turnstile_inputs(1, message: 'after mountAll()')
  end
end
