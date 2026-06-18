require 'test_helper'

require 'cloudflare/turnstile/rails/constants/cloudflare'
require 'cloudflare/turnstile/rails/helpers'

module Cloudflare
  module Turnstile
    module Rails
      class HelpersTest < ActionView::TestCase # rubocop:disable Metrics/ClassLength
        tests Helpers

        setup do
          # Reset configuration so each test starts from defaults.
          Rails.configuration = Configuration.new
          Rails.configure do |c|
            c.site_key = 'SITEKEY'
            c.secret_key = 'SECRETKEY'
            c.script_url = 'https://example.com/api.js'
          end
        end

        test 'default output includes the helper.js include and widget div' do
          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+src="[^"]*cloudflare_turnstile_helper\.js"[^>]*>/, html)
          assert_match %r{data-script-url="https://example\.com/api\.js"}, html
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

        test 'script tag is only rendered once when called multiple times' do
          first_html = cloudflare_turnstile_tag
          second_html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+src="[^"]*cloudflare_turnstile_helper\.js"[^>]*>/, first_html)
          assert_match(/<div[^>]+class="cf-turnstile"/, first_html)

          refute_match(/<script/, second_html)
          assert_match(/<div[^>]+class="cf-turnstile"/, second_html)
        end

        test 'script tag carries data-lazy-mount=true when lazy_mount is in effect' do
          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+data-lazy-mount="true"/, html)
        end

        test 'script tag carries data-lazy-mount=false when lazy_mount is disabled' do
          Rails.configuration.lazy_mount = false
          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+data-lazy-mount="false"/, html)
        end

        test 'script tag carries data-lazy-mount=false when render is auto (combo-4 misconfig)' do
          # lazy_mount = true (default) + render = 'auto' is invalid; the helper
          # forwards effective_lazy_mount, which degrades to false.
          Rails.configuration.render = 'auto'
          html = cloudflare_turnstile_tag

          assert_match(/<script[^>]+data-lazy-mount="false"/, html)
        end

        test 'widget div carries a min-height style by default to prevent layout shift' do
          html = cloudflare_turnstile_tag

          assert_match(/<div[^>]+style="min-height: 65px"/, html)
        end

        test 'min-height is omitted when caller supplies their own style' do
          html = cloudflare_turnstile_tag(style: 'width: 300px')

          assert_match(/style="width: 300px"/, html)
          refute_match(/min-height/, html)
        end

        test 'min-height is omitted when class is explicitly nil' do
          html = cloudflare_turnstile_tag(class: nil)

          refute_match(/min-height/, html)
        end

        test 'min-height is omitted for invisible widgets via data: hash' do
          html = cloudflare_turnstile_tag(data: { size: 'invisible' })

          refute_match(/min-height/, html)
          assert_match(/data-size="invisible"/, html)
        end

        test 'min-height is 120px for compact widgets to match Cloudflare iframe height' do
          html = cloudflare_turnstile_tag(data: { size: 'compact' })

          assert_match(/style="min-height: 120px"/, html)
        end

        test 'min-height is 65px for explicit normal/flexible sizes' do
          assert_match(/style="min-height: 65px"/, cloudflare_turnstile_tag(data: { size: 'normal' }))
          assert_match(/style="min-height: 65px"/, cloudflare_turnstile_tag(data: { size: 'flexible' }))
        end

        test 'data-size: literal html option also drives the reservation' do
          html = cloudflare_turnstile_tag('data-size': 'compact')

          assert_match(/style="min-height: 120px"/, html)
        end

        test 'min-height is omitted when lazy_mount is disabled' do
          Rails.configuration.lazy_mount = false
          html = cloudflare_turnstile_tag

          refute_match(/min-height/, html)
        end
      end
    end
  end
end
