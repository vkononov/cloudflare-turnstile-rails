require_relative 'constants/cloudflare'

module Cloudflare
  module Turnstile
    module Rails
      module Helpers
        # Heights Cloudflare's iframe settles at, keyed by `data-size`.
        # `compact` is 130x120; everything else (`normal`, `flexible`) is 65px
        # tall.
        COMPACT_RESERVATION_HEIGHT = 120
        DEFAULT_RESERVATION_HEIGHT = 65

        def cloudflare_turnstile_tag(site_key: nil, include_script: true, reserve_space: nil, **html_options) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
          config = Rails.configuration
          site_key ||= config.site_key
          html_options[:class] = Cloudflare::WIDGET_CLASS unless html_options.key?(:class)
          html_options[:data] = cloudflare_turnstile_default_data.merge(html_options[:data] || {})
          html_options[:data][:sitekey] ||= site_key
          reserve_turnstile_space(html_options, config, reserve_space)

          script_tag = nil
          if include_script && !@_ct_helper_rendered
            @_ct_helper_rendered = true

            # Emit exactly one tag:
            script_tag = javascript_include_tag(
              'cloudflare_turnstile_helper',
              async: true,
              defer: true,
              nonce: (defined?(content_security_policy_nonce) ? content_security_policy_nonce : nil),
              data: {
                'script-url': config.script_url,
                'mount-mode': config.effective_mount_mode
              }
            )
          end

          widget = content_tag(:div, '', html_options)
          safe_join([script_tag, widget].compact, "\n")
        end

        private

        # Resolves the configured default data attributes, evaluating any
        # callable values (e.g. a proc bound to I18n.locale) at render time.
        def cloudflare_turnstile_default_data
          (Rails.configuration.default_data || {}).transform_values do |value|
            value.respond_to?(:call) ? value.call : value
          end
        end

        # Records how much vertical space a lazily-mounted widget will need, so
        # the page doesn't jump (CLS) when Cloudflare finally swaps in the
        # iframe.
        #
        # We emit a plain `data-reserve-height` attribute and let the helper
        # script apply it as `el.style.minHeight`. Writing `style="..."` here
        # instead would need `style-src-attr 'unsafe-inline'`, which would
        # undercut the gem's whole CSP story — under a strict policy the
        # browser drops the attribute, the reservation silently stops working,
        # and the console fills with violations. Assigning `.style` from
        # JavaScript is not governed by CSP at all, so this route works
        # everywhere.
        #
        # Skipped when:
        #   * we're not lazy mounting (the iframe is already on its way),
        #   * reservation is switched off globally (config.reserve_space) or
        #     for this tag (reserve_space: false) — which is what you want for
        #     an invisible sitekey, since an invisible widget occupies no
        #     space at all, or
        #   * the caller passed `class: nil`, signalling that they're taking
        #     over the widget's styling.
        def reserve_turnstile_space(html_options, config, reserve_space)
          return unless config.effective_mount_mode == :lazy
          return unless reserve_space.nil? ? config.reserve_space : reserve_space
          return if html_options[:class].nil?

          html_options[:data][:reserve_height] = turnstile_reservation_height(html_options)
        end

        # Returns the px height to reserve for the configured widget size.
        #
        # Note that there is no case for invisible widgets here: visibility is
        # a property of the sitekey, set in the Cloudflare dashboard, and the
        # only valid `data-size` values are normal, flexible and compact. There
        # is nothing in the markup to detect, so invisible-sitekey apps opt out
        # via `config.reserve_space = false` instead.
        def turnstile_reservation_height(html_options)
          case turnstile_size(html_options).to_s
          when 'compact' then COMPACT_RESERVATION_HEIGHT
          else                DEFAULT_RESERVATION_HEIGHT
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
