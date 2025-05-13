require 'test_helper'

require 'cloudflare/turnstile/rails/railtie'

class RailtieTest < ActiveSupport::TestCase
  setup do
    @railtie = Cloudflare::Turnstile::Rails::Railtie

    # Manually run all of our Railtie's initializers so that
    # the ActiveSupport.on_load(:action_controller) and
    # on_load(:action_view) hooks actually get registered.
    @railtie.initializers.each { |initializer| initializer.run(nil) }
  end

  test 'defines controller_methods initializer' do
    names = @railtie.initializers.map(&:name)

    assert_includes names, 'cloudflare.turnstile.rails.controller_methods'
  end

  test 'defines helpers initializer' do
    names = @railtie.initializers.map(&:name)

    assert_includes names, 'cloudflare.turnstile.rails.helpers'
  end

  test 'ControllerMethods get mixed into ActionController::Base' do
    ActiveSupport.run_load_hooks(:action_controller, ActionController::Base)

    assert_includes ActionController::Base.included_modules,
                    Cloudflare::Turnstile::Rails::ControllerMethods
  end

  test 'Helpers get mixed into ActionView::Base' do
    ActiveSupport.run_load_hooks(:action_view, ActionView::Base)

    assert_includes ActionView::Base.included_modules,
                    Cloudflare::Turnstile::Rails::Helpers
  end
end
