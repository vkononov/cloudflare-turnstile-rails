module Cloudflare
  module Turnstile
    module Rails
      class Engine < ::Rails::Engine
        engine_name 'cloudflare_turnstile_rails'

        initializer 'cloudflare_turnstile.assets' do |app|
          js_path = ::Cloudflare::Turnstile::Rails::Engine.root.join(
            'lib', 'cloudflare', 'turnstile', 'rails', 'assets', 'javascripts'
          )
          app.config.assets.paths << js_path
          app.config.assets.precompile += %w[cloudflare_turnstile_helper.js]
        end

        initializer 'cloudflare_turnstile.i18n' do
          locale_path = File.expand_path('locales/*.yml', __dir__)
          I18n.load_path += Dir[locale_path]
        end
      end
    end
  end
end
