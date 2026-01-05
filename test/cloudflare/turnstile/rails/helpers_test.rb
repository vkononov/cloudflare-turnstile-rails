require 'test_helper'

require 'cloudflare/turnstile/rails/constants/cloudflare'
require 'cloudflare/turnstile/rails/helpers'

module Cloudflare
  module Turnstile
    module Rails
      class HelpersTest < ActionView::TestCase
        tests Helpers

        setup do
          Rails.configure do |c|
            c.site_key = 'SITEKEY'
            c.secret_key = 'SECRETKEY'
            c.script_url = 'https://example.com/api.js'
          end
        end

        test 'default output includes the helper.js include and widget div' do
          html = cloudflare_turnstile_tag

          # we should see exactly one <script> tag pointing at cloudflare_turnstile_helper.js
          assert_match(/<script[^>]+src="[^"]*cloudflare_turnstile_helper\.js"[^>]*>/, html)

          # that tag must carry our 'data-script-url' attribute with the configured URL
          assert_match %r{data-script-url="https://example\.com/api\.js"}, html

          # still render a widget container with the default class and data-sitekey
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
          # negative look-ahead for any class="…" attribute
          assert_match(/<div(?![^>]*\bclass=)/, html)
        end

        test 'nonce is passed through to the script tag when content_security_policy_nonce is defined' do
          def content_security_policy_nonce
            'NONCE123'
          end

          html = cloudflare_turnstile_tag

          # our include should carry nonce="NONCE123"
          assert_match(/<script[^>]+nonce="NONCE123"/, html)
        end

        test 'nonce attribute is absent when content_security_policy_nonce returns nil' do
          # Override to return nil (simulates CSP disabled or no nonce configured)
          def content_security_policy_nonce
            nil
          end

          html = cloudflare_turnstile_tag

          # The script tag should NOT have a nonce attribute
          refute_match(/nonce=/, html)
        end

        test 'passed-in site_key overrides the configured default' do
          html = cloudflare_turnstile_tag(site_key: 'OVERRIDE')

          assert_match(/data-sitekey="OVERRIDE"/, html)
        end
      end
    end
  end
end
