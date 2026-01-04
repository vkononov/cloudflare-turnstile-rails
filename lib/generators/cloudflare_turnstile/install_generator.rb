require 'rails_test_helper'
require 'rails/generators'

module CloudflareTurnstile
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Creates a Cloudflare Turnstile initializer.'

      def create_initializer
        copy_file 'cloudflare_turnstile.rb', 'config/initializers/cloudflare_turnstile.rb'
      end
    end
  end
end
