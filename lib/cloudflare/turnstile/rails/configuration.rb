module Cloudflare
  module Turnstile
    module Rails
      class Configuration
        attr_writer :script_url
        attr_accessor :site_key, :secret_key, :onload, :auto_populate_response_in_test_env

        def initialize
          @script_url = Cloudflare::SCRIPT_URL
          @site_key = nil
          @secret_key = nil
          @render = 'explicit'
          @render_explicitly_set = false
          @onload = nil
          @lazy_mount = true
          @lazy_mount_explicitly_set = false
          @auto_populate_response_in_test_env = true
        end

        attr_reader :render, :lazy_mount

        def render=(value)
          @render = value
          @render_explicitly_set = true
        end

        def lazy_mount=(value)
          @lazy_mount = value
          @lazy_mount_explicitly_set = true
        end

        def render_explicitly_set?
          @render_explicitly_set
        end

        def lazy_mount_explicitly_set?
          @lazy_mount_explicitly_set
        end

        # The fingerprint of a v1.x app upgrading to v2.0: the user set
        # `config.render = 'explicit'` (presumably because they were calling
        # `turnstile.render()` from their own JavaScript) but never touched
        # `config.lazy_mount` (which v2.0 introduced and defaults to true).
        #
        # Treating that as an automatic opt-out preserves the v1.x behaviour
        # — eager load, manual render — instead of silently flipping their
        # working app over to lazy mounting that would race their manual
        # render() calls. The companion warning in Railtie nudges them to
        # make their intent explicit.
        def v1_explicit_upgrade?
          @render_explicitly_set && !@lazy_mount_explicitly_set && @render == 'explicit'
        end

        # The lazy-mount machinery only does something useful when:
        #
        #   * api.js is served with ?render=explicit (otherwise Cloudflare's
        #     own auto-render observer mounts every widget the moment api.js
        #     arrives, defeating per-widget lazy triggers), AND
        #   * we're not looking at a v1.x app where the user is rendering
        #     widgets themselves (see v1_explicit_upgrade?).
        #
        # When either condition fails, lazy mounting is degraded to false
        # transparently and the helper script falls back to v1-style eager
        # load.
        def effective_lazy_mount
          return false if v1_explicit_upgrade?

          @lazy_mount && render == 'explicit'
        end

        def lazy_mount_misconfigured?
          @lazy_mount && render != 'explicit'
        end

        # Dynamically build the URL every time, so that
        # config.render and config.onload applied after init take effect.
        def script_url
          return @script_url unless @script_url == Cloudflare::SCRIPT_URL

          params = []
          params << "render=#{CGI.escape(@render)}" unless @render.nil?
          params << "onload=#{CGI.escape(@onload)}" unless @onload.nil?

          params.empty? ? Cloudflare::SCRIPT_URL : "#{Cloudflare::SCRIPT_URL}?#{params.join('&')}"
        end
      end
    end
  end
end
