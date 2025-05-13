require_relative 'controller_methods'
require_relative 'helpers'

module Cloudflare
  module Turnstile
    module Rails
      class Railtie < ::Rails::Railtie
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
      end
    end
  end
end
