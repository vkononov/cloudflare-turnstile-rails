module Cloudflare
  module Turnstile
    module Rails
      class Configuration
        attr_writer :script_url
        attr_accessor :site_key, :secret_key, :render, :onload

        def initialize
          @script_url = Cloudflare::SCRIPT_URL
          @site_key = nil
          @secret_key = nil
          @render = nil
          @onload = nil
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

        def validate!
          if site_key.nil? || site_key.strip.empty?
            raise ConfigurationError, 'Cloudflare Turnstile site_key is not set.'
          end

          return unless secret_key.nil? || secret_key.strip.empty?

          raise ConfigurationError, 'Cloudflare Turnstile secret_key is not set.'
        end
      end
    end
  end
end
