require_relative 'constants/cloudflare'

module Cloudflare
  module Turnstile
    module Rails
      module Helpers
        def cloudflare_turnstile_tag(site_key: nil, include_script: true, **html_options) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
          site_key ||= Rails.configuration.site_key
          html_options[:class] = Cloudflare::WIDGET_CLASS unless html_options.key?(:class)
          html_options[:data] ||= {}
          html_options[:data][:sitekey] ||= site_key

          script_tag = nil
          if include_script && !@_ct_helper_rendered
            @_ct_helper_rendered = true

            # Emit exactly one tag:
            script_tag = javascript_include_tag(
              'cloudflare_turnstile_helper',
              async: true,
              defer: true,
              nonce: (defined?(content_security_policy_nonce) ? content_security_policy_nonce : nil),
              data: { 'script-url': Rails.configuration.script_url }
            )
          end

          widget = content_tag(:div, '', html_options)
          safe_join([script_tag, widget].compact, "\n")
        end
      end
    end
  end
end
