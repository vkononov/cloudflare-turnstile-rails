require 'test_helper'

require 'cloudflare/turnstile/rails/constants/cloudflare'
require 'cloudflare/turnstile/rails/helpers'

module Cloudflare
  module Turnstile
    module Rails
      class HelpersTest < ActionView::TestCase # rubocop:disable Metrics/ClassLength
        tests Helpers

        setup do
          # Reset configuration so each test starts from defaults. The custom
          # script_url carries render=explicit so that the default mount mode
          # stays :lazy — see Configuration#explicit_render?.
          Rails.configuration = Configuration.new
          Rails.configure do |c|
            c.site_key = 'SITEKEY'
            c.secret_key = 'SECRETKEY'
            c.script_url = 'https://example.com/api.js?render=explicit'
            c.default_data = {}
          end
        end

        test 'default output includes the helper.js include and widget div' do
          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+src="[^"]*cloudflare_turnstile_helper\.js"[^>]*>/, html)
          assert_match %r{data-script-url="https://example\.com/api\.js\?render=explicit"}, html
          assert_match(/<div[^>]+class="cf-turnstile"[^>]+data-sitekey="SITEKEY"/, html)
        end

        test 'omitting script when include_script: false' do
          html = cloudflare_turnstile_tag(include_script: false)

          refute_match(/<script/, html)
          assert_match(/<div[^>]+class="cf-turnstile"/, html)
        end

        test 'custom html_options override default class and data' do
          html = cloudflare_turnstile_tag(class: 'my-class', data: { foo: 'bar' })

          assert_match(/<div[^>]+class="my-class"/, html)
          assert_match(/data-foo="bar"/, html)
          assert_match(/data-sitekey="SITEKEY"/, html)
        end

        test 'explicitly nil class results in no class attribute' do
          html = cloudflare_turnstile_tag(class: nil)

          assert_match(/<div(?![^>]*\bclass=)/, html)
        end

        test 'nonce is passed through to the script tag when content_security_policy_nonce is defined' do
          def content_security_policy_nonce
            'NONCE123'
          end

          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+nonce="NONCE123"/, html)
        end

        test 'nonce attribute is absent when content_security_policy_nonce returns nil' do
          def content_security_policy_nonce
            nil
          end

          html = cloudflare_turnstile_tag

          refute_match(/nonce=/, html)
        end

        test 'passed-in site_key overrides the configured default' do
          html = cloudflare_turnstile_tag(site_key: 'OVERRIDE')

          assert_match(/data-sitekey="OVERRIDE"/, html)
        end

        test 'configured default_data is applied to the widget' do
          Rails.configuration.default_data = { theme: 'light', language: 'en' }

          html = cloudflare_turnstile_tag

          assert_match(/data-theme="light"/, html)
          assert_match(/data-language="en"/, html)
          assert_match(/data-sitekey="SITEKEY"/, html)
        end

        test 'per-tag data overrides configured default_data' do
          Rails.configuration.default_data = { theme: 'light', language: 'en' }

          html = cloudflare_turnstile_tag(data: { theme: 'dark' })

          # overridden key wins
          assert_match(/data-theme="dark"/, html)
          # non-overridden default is preserved
          assert_match(/data-language="en"/, html)
        end

        test 'callable default_data values are evaluated at render time' do
          Rails.configuration.default_data = { language: -> { 'fr' } }

          html = cloudflare_turnstile_tag

          assert_match(/data-language="fr"/, html)
        end

        test 'passing nil for a default_data key drops the attribute for that tag' do
          Rails.configuration.default_data = { theme: 'light', language: 'en' }

          html = cloudflare_turnstile_tag(data: { theme: nil })

          # nil value removes the attribute entirely rather than rendering data-theme=""
          refute_match(/data-theme=/, html)
          # other defaults remain untouched
          assert_match(/data-language="en"/, html)
        end

        test 'script tag is only rendered once when called multiple times' do
          first_html = cloudflare_turnstile_tag
          second_html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+src="[^"]*cloudflare_turnstile_helper\.js"[^>]*>/, first_html)
          assert_match(/<div[^>]+class="cf-turnstile"/, first_html)

          refute_match(/<script/, second_html)
          assert_match(/<div[^>]+class="cf-turnstile"/, second_html)
        end

        test 'script tag carries data-mount-mode=lazy by default' do
          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+data-mount-mode="lazy"/, html)
        end

        test 'script tag carries data-mount-mode=eager when lazy_mount is disabled' do
          Rails.configuration.lazy_mount = false
          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+data-mount-mode="eager"/, html)
        end

        test 'script tag carries data-mount-mode=eager when render is auto' do
          Rails.configuration.script_url = Cloudflare::SCRIPT_URL
          Rails.configuration.render = 'auto'
          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+data-mount-mode="eager"/, html)
        end

        test 'script tag carries data-mount-mode=eager when a custom url omits render=explicit' do
          Rails.configuration.script_url = 'https://example.com/api.js'
          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+data-mount-mode="eager"/, html)
        end

        test 'script tag carries data-mount-mode=passive when manual_render is set' do
          Rails.configuration.manual_render = true
          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+data-mount-mode="passive"/, html)
        end

        test 'widget div reserves height via a data attribute to prevent layout shift' do
          html = cloudflare_turnstile_tag

          assert_match(/<div[^>]+data-reserve-height="65"/, html)
        end

        test 'no inline style attribute is emitted, so no style-src-attr unsafe-inline is needed' do
          html = cloudflare_turnstile_tag

          refute_match(/style=/, html,
                       'an inline style attribute would require unsafe-inline and break strict CSP')
        end

        test 'reserved height is 120 for compact widgets to match the Cloudflare iframe' do
          html = cloudflare_turnstile_tag(data: { size: 'compact' })

          assert_match(/data-reserve-height="120"/, html)
        end

        test 'reserved height is 65 for explicit normal and flexible sizes' do
          assert_match(/data-reserve-height="65"/, cloudflare_turnstile_tag(data: { size: 'normal' }))
          assert_match(/data-reserve-height="65"/, cloudflare_turnstile_tag(data: { size: 'flexible' }))
        end

        test 'a literal data-size html option also drives the reservation' do
          html = cloudflare_turnstile_tag('data-size': 'compact')

          assert_match(/data-reserve-height="120"/, html)
        end

        test 'a caller-supplied style is left alone and still gets a reservation' do
          # The reservation is applied from JavaScript now, so it no longer
          # competes with the caller's own style attribute.
          html = cloudflare_turnstile_tag(style: 'width: 300px')

          assert_match(/style="width: 300px"/, html)
          assert_match(/data-reserve-height="65"/, html)
        end

        test 'reservation is omitted when class is explicitly nil' do
          html = cloudflare_turnstile_tag(class: nil)

          refute_match(/data-reserve-height/, html)
        end

        test 'reservation is omitted for a custom class the helper script never mounts' do
          # The helper only observes `.cf-turnstile`, so nothing would ever
          # apply or release a reservation on this element. Emitting one would
          # be inert and misleading.
          html = cloudflare_turnstile_tag(class: 'my-widget')

          refute_match(/data-reserve-height/, html)
        end

        test 'reservation still applies when the widget class is one of several' do
          html = cloudflare_turnstile_tag(class: 'mb-4 cf-turnstile border')

          assert_match(/data-reserve-height="65"/, html)
        end

        test 'reservation still applies when the class is given as an array' do
          html = cloudflare_turnstile_tag(class: %w[mb-4 cf-turnstile])

          assert_match(/data-reserve-height="65"/, html)
        end

        test 'reservation is omitted when not lazy mounting' do
          Rails.configuration.lazy_mount = false
          html = cloudflare_turnstile_tag

          refute_match(/data-reserve-height/, html)
        end

        test 'reservation is omitted when config.reserve_space is false' do
          # The supported escape hatch for an invisible sitekey, which occupies
          # no space and therefore needs none reserved.
          Rails.configuration.reserve_space = false
          html = cloudflare_turnstile_tag

          refute_match(/data-reserve-height/, html)
        end

        test 'reservation is omitted for a single tag via reserve_space: false' do
          html = cloudflare_turnstile_tag(reserve_space: false)

          refute_match(/data-reserve-height/, html)
          assert_match(/class="cf-turnstile"/, html)
        end

        test 'reserve_space: true re-enables reservation for one tag when disabled globally' do
          Rails.configuration.reserve_space = false
          html = cloudflare_turnstile_tag(reserve_space: true)

          assert_match(/data-reserve-height="65"/, html)
        end

        test 'reserve_space is not emitted as a data attribute on the widget' do
          html = cloudflare_turnstile_tag(reserve_space: false)

          refute_match(/reserve-space/, html)
        end
      end
    end
  end
end
