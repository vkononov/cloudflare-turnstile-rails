require_relative 'rails/configuration'
require_relative 'rails/constants/cloudflare'
require_relative 'rails/engine'
require_relative 'rails/railtie'

module Cloudflare
  module Turnstile
    module Rails
      class Error < StandardError; end
      class ConfigurationError < Error; end

      def self.configuration
        @configuration ||= Configuration.new
      end

      def self.configuration=(config)
        @configuration = config
      end

      def self.configure
        yield(configuration)
      end
    end
  end
end
