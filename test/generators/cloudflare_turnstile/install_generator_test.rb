require 'test_helper'

require 'generators/cloudflare_turnstile/install_generator'

class InstallGeneratorTest < Rails::Generators::TestCase
  tests CloudflareTurnstile::Generators::InstallGenerator
  destination File.expand_path('../tmp', __dir__)
  setup :prepare_destination

  def test_creates_initializer
    run_generator
    assert_file 'config/initializers/cloudflare_turnstile.rb' do |content|
      assert_match(/Cloudflare::Turnstile::Rails\.configure/, content)
      assert_match(/config\.site_key/, content)
      assert_match(/config\.secret_key/, content)
    end
  end
end
