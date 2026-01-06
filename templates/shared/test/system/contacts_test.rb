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

  private

  def wait_for_turnstile_inputs(count, timeout: 5, message: nil) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    start = Time.now
    stable_since = nil
    context = message ? " (#{message})" : ''
    size = 0

    loop do
      begin
        inputs = all("div.cf-turnstile input[name='cf-turnstile-response']", visible: :all)
        size = inputs.size

        if size == count && inputs.all? { |i| i.value.to_s.strip != '' }
          stable_since ||= Time.now
          return if Time.now - stable_since > 0.5
        elsif size > count
          flunk "Expected #{count} Turnstile widgets, but found #{size}#{context}"
        else
          stable_since = nil
        end
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        stable_since = nil
      end

      flunk "Timed out waiting for #{count} Turnstile widgets; saw #{size}#{context}" if Time.now - start > timeout

      sleep 0.1
    end
  end
end
