require_relative 'controller_methods'
require_relative 'helpers'

module Cloudflare
  module Turnstile
    module Rails
      class Railtie < ::Rails::Railtie
        UPGRADE_GUIDE_URL = 'https://github.com/vkononov/cloudflare-turnstile-rails#upgrading-from-v1x-to-v20'.freeze

        initializer 'cloudflare.turnstile.rails.controller_methods' do
          ActiveSupport.on_load(:action_controller) do
            include Rails::ControllerMethods
          end
        end

        initializer 'cloudflare.turnstile.rails.helpers' do
          ActiveSupport.on_load(:action_view) do
            include Rails::Helpers
          end
        end

        initializer 'cloudflare.turnstile.rails.upgrade_warning' do |app|
          # `app` is nil when initializers are invoked outside of a Rails
          # application boot (notably in this gem's own unit tests). Bail
          # gracefully so the bare `Railtie.initializers.each(&:run)` idiom
          # keeps working there.
          app&.config&.after_initialize do
            Railtie.emit_upgrade_warnings
          end
        end

        def self.emit_upgrade_warnings
          # Use ::Cloudflare to avoid colliding with the nested constants module
          # at Cloudflare::Turnstile::Rails::Cloudflare.
          config = ::Cloudflare::Turnstile::Rails.configuration

          warn_lazy_mount_misconfiguration(config)
          warn_manual_render_misconfiguration(config)
        end

        def self.warn_lazy_mount_misconfiguration(config)
          return unless config.lazy_mount_misconfigured?

          ::Rails.logger&.warn(
            '[cloudflare-turnstile-rails] config.lazy_mount = true needs an api.js URL ' \
            "carrying render=explicit, but #{config.script_url} does not. Cloudflare's " \
            'auto-render observer will mount every widget as soon as api.js arrives, so ' \
            'the lazy-mount triggers have nothing left to defer. The gem has fallen back ' \
            'to eager mounting. Either drop the override so render=explicit is applied ' \
            '(recommended), add render=explicit to your config.script_url, or set ' \
            "config.lazy_mount = false to silence this notice. See: #{UPGRADE_GUIDE_URL}"
          )
        end

        def self.warn_manual_render_misconfiguration(config)
          return unless config.manual_render_misconfigured?

          ::Rails.logger&.warn(
            '[cloudflare-turnstile-rails] config.manual_render = true means your app calls ' \
            "turnstile.render() itself, but #{config.script_url} does not carry " \
            "render=explicit. Cloudflare's auto-render observer will mount every widget as " \
            'soon as api.js arrives, and your own render() call will then fail with error ' \
            '300030 (widget already rendered). Either drop the override so render=explicit is ' \
            'applied (recommended), add render=explicit to your config.script_url, or stop ' \
            "calling turnstile.render() yourself. See: #{UPGRADE_GUIDE_URL}"
          )
        end
      end
    end
  end
end
