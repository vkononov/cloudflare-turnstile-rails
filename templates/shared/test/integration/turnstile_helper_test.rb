require 'test_helper'

# Integration-level coverage for the markup that `cloudflare_turnstile_tag`
# emits. Anything that does NOT require a JS-capable browser belongs here:
# rendered HTML, helper-script attributes, CLS placeholder styling, and the
# server-side verification round-trip. The browser-driven mounting flow is
# covered by the system tests under `test/system/`.
class TurnstileHelperTest < ActionDispatch::IntegrationTest
  include Rails.application.routes.url_helpers

  setup do
    Cloudflare::Turnstile::Rails.configure do |config|
      config.site_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', '1x00000000000000000000AA')
      config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', '1x0000000000000000000000000000000AA')
      config.render = 'explicit'
      config.lazy_mount = true
    end
  end

  # Several tests below mutate `lazy_mount`, `manual_render` and `render`
  # to verify opt-out paths. Without restoring defaults afterwards those
  # mutated values would bleed into other test files (e.g. the system
  # tests), which would suddenly see `data-mount-mode="eager"` in the
  # helper script and never lazily mount their widgets. Process-wide
  # config means process-wide cleanup.
  teardown do
    Cloudflare::Turnstile::Rails.configure do |config|
      config.render = 'explicit'
      config.lazy_mount = true
      config.manual_render = false
      config.reserve_space = true
    end
  end

  test 'helper script tag carries v2 lazy-mount attributes by default' do
    get new_contact_url

    assert_response :success
    assert_select 'script[data-mount-mode="lazy"]', count: 1
    assert_select 'script[data-script-url*=?]', 'render=explicit', count: 1
    assert_select 'script[async][defer]', count: 1
  end

  test 'widget div reserves vertical space to prevent layout shift' do
    get new_contact_url

    assert_response :success
    assert_select 'div.cf-turnstile[data-reserve-height="65"]', count: 1
  end

  test 'the reservation needs no inline style, so strict CSP needs no style-src-attr' do
    get new_contact_url

    assert_response :success
    assert_select 'div.cf-turnstile[style]', count: 0
  end

  test 'the CLS reservation can be switched off for space-less sitekeys' do
    Cloudflare::Turnstile::Rails.configuration.reserve_space = false

    get new_contact_url

    assert_response :success
    assert_select 'div.cf-turnstile', count: 1
    assert_select 'div.cf-turnstile[data-reserve-height]', count: 0
  end

  test 'multiple widgets on one page share a single helper script tag' do
    get new2_books_url

    assert_response :success
    assert_select 'div.cf-turnstile', count: 2
    assert_select 'script[data-mount-mode]', count: 1
  end

  test 'opting out of lazy mount switches to eager mode and drops the CLS reservation' do
    Cloudflare::Turnstile::Rails.configuration.lazy_mount = false

    get new_contact_url

    assert_response :success
    assert_select 'script[data-mount-mode="eager"]', count: 1
    # Nothing to reserve when the iframe mounts before the first paint.
    assert_select 'div.cf-turnstile[data-reserve-height]', count: 0
  end

  test 'manual_render puts the gem in passive mode' do
    Cloudflare::Turnstile::Rails.configuration.manual_render = true

    get new_contact_url

    assert_response :success
    assert_select 'script[data-mount-mode="passive"]', count: 1
    assert_select 'div.cf-turnstile[data-reserve-height]', count: 0
  end

  test "render='auto' falls back to eager mode and drops render=explicit from the script URL" do
    Cloudflare::Turnstile::Rails.configuration.render = 'auto'

    get new_contact_url

    assert_response :success
    assert_select 'script[data-mount-mode="eager"]', count: 1
    assert_select 'script[data-script-url*=?]', 'render=auto', count: 1
  end

  test 'server-side verification accepts a Turnstile-protected POST in test env' do
    Cloudflare::Turnstile::Rails.configuration.auto_populate_response_in_test_env = true

    post contact_url

    assert_redirected_to root_url
    assert_equal 'Message sent successfully.', flash[:notice]
  end

  test 'server-side verification rejects a Turnstile-protected POST when the secret is wrong' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = '2x0000000000000000000000000000000AA'

    post contact_url

    assert_redirected_to new_contact_url
    assert_equal Cloudflare::Turnstile::Rails::ErrorMessage.default, flash[:alert]
  end
end
