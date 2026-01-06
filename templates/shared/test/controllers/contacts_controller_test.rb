require 'test_helper'

class ContactsControllerTest < ActionDispatch::IntegrationTest
  include Rails.application.routes.url_helpers

  setup do
    Cloudflare::Turnstile::Rails.configure do |config|
      config.site_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', '1x00000000000000000000AA')
      config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', '1x0000000000000000000000000000000AA')
    end
  end

  test 'GET /contact/new renders the contact form' do
    get new_contact_url

    assert_response :success
    assert_select 'form#contact-form'
    assert_select 'div.cf-turnstile', count: 1
  end

  test 'POST /contact with passing Turnstile → redirect with notice' do
    Cloudflare::Turnstile::Rails.configuration.auto_populate_response_in_test_env = true
    post contact_url

    assert_redirected_to root_url
    assert_equal 'Message sent successfully.', flash[:notice]
  end

  test 'POST /contact with failing Turnstile → redirect with flash alert' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = '2x0000000000000000000000000000000AA'
    post contact_url

    assert_redirected_to new_contact_url
    assert_equal Cloudflare::Turnstile::Rails::ErrorMessage.default, flash[:alert]
  end
end
