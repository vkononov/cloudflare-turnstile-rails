require 'test_helper'

require 'cloudflare/turnstile/rails/version'

module Cloudflare
  module Turnstile
    class TestRails < Minitest::Test
      def test_that_it_has_a_version_number
        refute_nil ::Cloudflare::Turnstile::Rails::VERSION
      end
    end
  end
end
