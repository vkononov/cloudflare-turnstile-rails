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

        # The lazy-mount machinery only does something useful when api.js is
        # served with ?render=explicit. With render='auto' Cloudflare auto-renders
        # every widget the moment api.js arrives, so per-widget lazy triggers can't
        # have any effect. Detect that combination and degrade transparently.
        def effective_lazy_mount
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
