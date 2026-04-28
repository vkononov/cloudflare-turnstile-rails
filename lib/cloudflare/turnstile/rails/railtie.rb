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
          warn_v1_explicit_upgrade(config)
          warn_lazy_mount_misconfiguration(config)
        end

        def self.warn_v1_explicit_upgrade(config)
          return unless config.render_explicitly_set?
          return unless config.render == 'explicit'
          return if config.lazy_mount_explicitly_set?

          ::Rails.logger&.warn(
            "[cloudflare-turnstile-rails] You have config.render = 'explicit' but no " \
            'config.lazy_mount setting. v2.0 introduced config.lazy_mount (default true), ' \
            'which may conflict with manual turnstile.render() calls from v1.x. Set ' \
            'config.lazy_mount explicitly (true or false) to silence this notice. ' \
            "See: #{UPGRADE_GUIDE_URL}"
          )
        end

        def self.warn_lazy_mount_misconfiguration(config)
          return unless config.lazy_mount_misconfigured?

          ::Rails.logger&.warn(
            '[cloudflare-turnstile-rails] config.lazy_mount = true requires ' \
            "config.render = 'explicit' to take effect. Cloudflare's auto-render " \
            'observer will mount every widget as soon as api.js arrives, so the ' \
            'lazy-mount triggers cannot work. Either set config.render = ' \
            "'explicit' (recommended) or set config.lazy_mount = false to silence " \
            "this notice. See: #{UPGRADE_GUIDE_URL}"
          )
        end
      end
    end
  end
end
