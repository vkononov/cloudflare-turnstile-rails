require_relative 'constants/cloudflare'

module Cloudflare
  module Turnstile
    module Rails
      module Helpers
        def cloudflare_turnstile_tag(site_key: nil, include_script: true, **html_options) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
          config = Rails.configuration
          site_key ||= config.site_key
          html_options[:class] = Cloudflare::WIDGET_CLASS unless html_options.key?(:class)
          html_options[:data] ||= {}
          html_options[:data][:sitekey] ||= site_key
          reserve_turnstile_space(html_options, config)

          script_tag = nil
          if include_script && !@_ct_helper_rendered
            @_ct_helper_rendered = true

            script_tag = javascript_include_tag(
              'cloudflare_turnstile_helper',
              async: true,
              defer: true,
              nonce: (defined?(content_security_policy_nonce) ? content_security_policy_nonce : nil),
              data: {
                'script-url': config.script_url,
                'lazy-mount': config.effective_lazy_mount.to_s
              }
            )
          end

          widget = content_tag(:div, '', html_options)
          safe_join([script_tag, widget].compact, "\n")
        end

        private

        # Reserves a placeholder height while the lazy-mounted widget is
        # waiting in the wings, so the page doesn't jump (CLS) when Cloudflare
        # finally swaps in the iframe. The reserved height matches what
        # Cloudflare's iframe will eventually render at:
        #
        #   * normal / flexible widgets   → 65 px (Cloudflare hard-codes this)
        #   * compact widgets             → 120 px (compact is 130×120)
        #   * invisible widgets           → no reservation; they take no space
        #
        # We only reserve when:
        #   * lazy mounting is actually in effect (effective_lazy_mount),
        #   * the caller hasn't disabled our default class (class: nil),
        #   * the caller hasn't supplied their own style attribute, and
        #   * the widget isn't an invisible variant.
        def reserve_turnstile_space(html_options, config)
          return unless config.effective_lazy_mount
          return if html_options[:class].nil?
          return if html_options.key?(:style)

          height = turnstile_reservation_height(html_options)
          return if height.nil?

          html_options[:style] = "min-height: #{height}px"
        end

        # Returns the px height to reserve for the configured widget size, or
        # nil when no reservation is appropriate (invisible widgets).
        def turnstile_reservation_height(html_options)
          case turnstile_size(html_options).to_s
          when 'invisible' then nil
          when 'compact'   then 120
          else                  65
          end
        end

        # Resolves the widget's `data-size` from either the symbol/string
        # `:data` hash or a literal `data-size:` html option.
        def turnstile_size(html_options)
          data = html_options[:data] || {}
          data[:size] || data['size'] || html_options[:'data-size'] || html_options['data-size']
        end
      end
    end
  end
end
