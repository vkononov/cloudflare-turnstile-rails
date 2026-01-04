require 'application_system_test_case'

class BooksTest < ApplicationSystemTestCase
  setup do
    Cloudflare::Turnstile::Rails.configure do |config|
      config.site_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SITE_KEY', '1x00000000000000000000AA')
      config.secret_key = ENV.fetch('CLOUDFLARE_TURNSTILE_SECRET_KEY', '1x0000000000000000000000000000000AA')
    end
  end

  test 'visiting the from from another page renders turnstile' do
    visit root_url
    click_on 'New Book'
    wait_for_turnstile_inputs(1)

    assert_selector "div.cf-turnstile input[name='cf-turnstile-response']", count: 1, visible: :all
  end

  test 'visiting the page twice does not render turnstile twice' do
    visit new_book_url
    wait_for_turnstile_inputs(1)
    visit new_book_url
    wait_for_turnstile_inputs(1)

    assert_selector "div.cf-turnstile input[name='cf-turnstile-response']", count: 1, visible: :all
  end

  test 'submitting the form with a validation error re-renders turnstile' do
    visit new_book_url
    wait_for_turnstile_inputs(1)
    click_on 'Create Book'

    assert_text "Title can't be blank"
    wait_for_turnstile_inputs(1)
  end

  test 'submitting the form with a valid book re-renders turnstile' do
    visit new_book_url
    wait_for_turnstile_inputs(1)
    fill_in 'Title', with: "Wizard's First Rule"
    click_on 'Create Book'

    assert_text 'Book was successfully created'
    wait_for_turnstile_inputs(1)
  end

  test 'submitting the form before turnstile is ready passed when response is auto populated' do
    visit new_book_url
    click_on 'Create Book'
    wait_for_turnstile_inputs(1)

    assert_selector 'li', text: "Title can't be blank"
  end

  test 'turnstile does not render when site key is invalid' do
    Cloudflare::Turnstile::Rails.configuration.site_key = 'DUMMY'
    visit new_book_url

    assert_no_selector(turnstile_selector, visible: :all, wait: 5)
  end

  test 'turnstile returns an error when secret key is invalid' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = 'DUMMY'
    visit new_book_url
    wait_for_turnstile_inputs(1)
    click_on 'Create Book'

    assert_text Cloudflare::Turnstile::Rails::ErrorMessage.default
    wait_for_turnstile_inputs(1)
  end

  test 'turnstile validation fails when human verification fails' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = '2x0000000000000000000000000000000AA'
    visit new_book_url
    wait_for_turnstile_inputs(1)
    click_on 'Create Book'

    assert_text Cloudflare::Turnstile::Rails::ErrorMessage.default
    wait_for_turnstile_inputs(1)
  end

  test 'turnstile validation fails when the token is expired' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = '3x0000000000000000000000000000000AA'
    visit new_book_url
    wait_for_turnstile_inputs(1)
    click_on 'Create Book'

    assert_text Cloudflare::Turnstile::Rails::ErrorMessage.default
    wait_for_turnstile_inputs(1)
  end

  test 'turnstile renders two plugins when there are two forms' do
    skip "Not supported in Github actions for Ruby v#{RUBY_VERSION}" if RUBY_VERSION < '2.7.0' && ENV['CI']

    visit new2_books_url
    wait_for_turnstile_inputs(2)
    all('input[type="submit"]').each { |input| input.click and wait_for_turnstile_inputs(2) }

    assert_selector 'li', text: "Title can't be blank", count: 2, wait: 5
  end

  private

  def turnstile_selector
    "div.cf-turnstile input[name='cf-turnstile-response'][value*='DUMMY']"
  end

  def wait_for_turnstile_inputs(count, timeout: 5) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    start = Time.now
    stable_since = nil

    loop do
      inputs = all("div.cf-turnstile input[name='cf-turnstile-response']", visible: :all)
      size = inputs.size

      if size == count && inputs.all? { |i| i.value.to_s.strip != '' }
        # once we hit the desired size with nonempty values,
        # wait a moment to make sure it’s stable
        stable_since ||= Time.now
        return if Time.now - stable_since > 0.5
      elsif size > count
        flunk "Expected #{count} Turnstile widgets, but found #{size}"
      else
        # reset the stability countdown if size changed
        stable_since = nil
      end

      flunk "Timed out waiting for #{count} Turnstile widgets; saw #{size}" if Time.now - start > timeout

      sleep 0.1
    end
  end
end
