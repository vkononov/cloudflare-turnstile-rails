require 'test_helper'

require 'pathname'
require 'cloudflare/turnstile/rails/engine'

class EngineTest < Minitest::Test
  def setup
    @engine = Cloudflare::Turnstile::Rails::Engine
    # build a fake app with only the bits our initializer touches:
    assets = Struct.new(:paths, :precompile).new([], [])
    config = Struct.new(:assets).new(assets)
    @app = Struct.new(:config).new(config)

    @initializer = @engine.initializers.find { |i| i.name == 'cloudflare_turnstile.assets' }
  end

  def test_that_initializer_is_defined
    assert @initializer, "Expected an initializer named 'cloudflare_turnstile.assets'"
  end

  def test_assets_path_is_added
    fake_root = Pathname.new('/fake/engine/root')
    @engine.stub :root, fake_root do
      @initializer.run(@app)
      expected = fake_root.join('lib', 'cloudflare', 'turnstile', 'rails', 'assets', 'javascripts')

      assert_includes @app.config.assets.paths,
                      expected,
                      "Should append #{expected} to app.config.assets.paths"
    end
  end

  def test_helper_js_is_precompiled
    fake_root = Pathname.new('/fake/engine/root')
    @engine.stub :root, fake_root do
      @initializer.run(@app)

      assert_includes @app.config.assets.precompile,
                      'cloudflare_turnstile_helper.js',
                      'Should add cloudflare_turnstile_helper.js to app.config.assets.precompile'
    end
  end
end
