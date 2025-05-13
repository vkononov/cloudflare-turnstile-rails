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
      end
    end
  end
end
