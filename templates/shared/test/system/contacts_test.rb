require 'application_system_test_case'

class ContactsTest < ApplicationSystemTestCase
  setup do
    Cloudflare::Turnstile::Rails.configure do |config|
      config.site_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', '1x00000000000000000000AA')
      config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', '1x0000000000000000000000000000000AA')
    end
  end

  test 'visiting contact page renders turnstile widget' do
    visit new_contact_url
    wait_for_turnstile_inputs(1)

    assert_selector "div.cf-turnstile input[name='cf-turnstile-response']", count: 1, visible: :all
  end

  test 'submitting contact form with passing turnstile shows success notice' do
    visit new_contact_url
    wait_for_turnstile_inputs(1)
    click_on 'Send Message'

    assert_text 'Message sent successfully.'
  end

  test 'submitting contact form with failing turnstile shows flash alert' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = '2x0000000000000000000000000000000AA'
    visit new_contact_url
    wait_for_turnstile_inputs(1)
    click_on 'Send Message'

    assert_text Cloudflare::Turnstile::Rails::ErrorMessage.default
  end
end
