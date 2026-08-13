require 'cgi'
require 'uri'

module Cloudflare
  module Turnstile
    module Rails
      class Configuration
        attr_writer :script_url
        attr_accessor :site_key, :secret_key, :render, :onload, :default_data, :lazy_mount, :manual_render,
                      :reserve_space, :auto_populate_response_in_test_env

        def initialize
          @script_url = Cloudflare::SCRIPT_URL
          @site_key = nil
          @secret_key = nil
          @render = 'explicit'
          @onload = nil
          @lazy_mount = true
          @manual_render = false
          @reserve_space = true
          @default_data = {}
          @auto_populate_response_in_test_env = true
        end

        # True when the api.js URL we are actually going to load carries
        # `render=explicit`.
        #
        # This is deliberately derived from the resolved #script_url rather
        # than from @render, because a custom `config.script_url` is used
        # verbatim and never has render/onload appended. Reading @render would
        # claim explicit rendering for a URL that doesn't ask for it, leaving
        # Cloudflare's auto-render observer to mount every widget the moment
        # api.js arrives — silently defeating lazy mounting and risking a
        # double render (Turnstile error 300030).
        def explicit_render?
          query = URI.parse(script_url).query
          return false if query.nil?

          URI.decode_www_form(query).any? { |key, value| key == 'render' && value == 'explicit' }
        rescue URI::InvalidURIError, ArgumentError
          # A URL we can't parse is a URL we can't vouch for. Treating it as
          # non-explicit is the safe direction: the gem falls back to eager
          # mounting and warns, rather than lazily deferring widgets that
          # Cloudflare may already be rendering.
          false
        end

        # Resolves the configuration into the one mode the helper script runs in:
        #
        #   :lazy    - the gem renders widgets, deferred until each one is
        #              actually needed (scrolled near, form interacted with,
        #              revealed, or mounted by hand).
        #   :eager   - the gem renders every widget as soon as api.js is ready
        #              and keeps doing so across Turbo navigations and DOM
        #              mutations. This is v1.x behaviour.
        #   :passive - the gem loads api.js and renders nothing at all; the
        #              host app calls turnstile.render() itself.
        #
        # Note that :eager, not :passive, is the fallback when the URL isn't
        # explicit. With Cloudflare auto-rendering, our sweep is a guarded
        # no-op for widgets it already handled (see isAlreadyMounted in the
        # helper) but still covers ones it missed — same belt-and-braces
        # arrangement v1.x shipped.
        def effective_mount_mode
          return :passive if manual_render
          return :eager unless explicit_render?
          return :eager unless lazy_mount

          :lazy
        end

        # Lazy mounting needs `render=explicit` to mean anything: without it
        # Cloudflare mounts everything up front and there is nothing left to
        # defer. Catches both `config.render = 'auto'` and a custom
        # `config.script_url` that omits the parameter.
        def lazy_mount_misconfigured?
          lazy_mount && !manual_render && !explicit_render?
        end

        # Whether to reserve vertical space for a widget, to absorb the layout
        # shift when Cloudflare swaps the iframe in.
        #
        # Space is only worth reserving in :lazy mode — in the other modes the
        # iframe is on its way before the first paint, so there is no shift to
        # absorb.
        #
        # `override` carries the per-tag `reserve_space:` option, where nil
        # means "the caller didn't say" and the global setting decides. This is
        # the single source of truth for the rule: the view helper asks rather
        # than reimplementing it, so the two can't drift apart.
        def reserve_space?(override = nil)
          return false unless effective_mount_mode == :lazy

          override.nil? ? reserve_space : override
        end

        # Dynamically build the URL every time, so that
        # config.render and config.onload applied after init take effect.
        def script_url
          return @script_url unless @script_url == Cloudflare::SCRIPT_URL

          # Otherwise, append render/onload if present:
          params = []
          params << "render=#{CGI.escape(@render)}" unless @render.nil?
          params << "onload=#{CGI.escape(@onload)}" unless @onload.nil?

          params.empty? ? Cloudflare::SCRIPT_URL : "#{Cloudflare::SCRIPT_URL}?#{params.join('&')}"
        end
      end
    end
  end
end
