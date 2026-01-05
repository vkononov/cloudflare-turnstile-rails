require 'application_system_test_case'

class BooksTest < ApplicationSystemTestCase # rubocop:disable Metrics/ClassLength
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
    wait_for_turnstile_inputs(1, message: 'after first visit')
    visit new_book_url
    wait_for_turnstile_inputs(1, message: 'after second visit')

    assert_selector "div.cf-turnstile input[name='cf-turnstile-response']", count: 1, visible: :all
  end

  test 'submitting the form with a validation error re-renders turnstile' do
    visit new_book_url
    wait_for_turnstile_inputs(1, message: 'after page load')
    click_on 'Create Book'

    assert_text "Title can't be blank"
    wait_for_turnstile_inputs(1, message: 'after validation error')
  end

  test 'submitting the form with a valid book re-renders turnstile' do
    visit new_book_url
    wait_for_turnstile_inputs(1, message: 'after page load')
    fill_in 'Title', with: "Wizard's First Rule"
    click_on 'Create Book'

    assert_text 'Book was successfully created'
    wait_for_turnstile_inputs(1, message: 'after successful submit')
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
    wait_for_turnstile_inputs(1, message: 'after page load')
    click_on 'Create Book'

    assert_text Cloudflare::Turnstile::Rails::ErrorMessage.default
    wait_for_turnstile_inputs(1, message: 'after submit with invalid secret')
  end

  test 'turnstile validation fails when human verification fails' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = '2x0000000000000000000000000000000AA'
    visit new_book_url
    wait_for_turnstile_inputs(1, message: 'after page load')
    click_on 'Create Book'

    assert_text Cloudflare::Turnstile::Rails::ErrorMessage.default
    wait_for_turnstile_inputs(1, message: 'after failed verification')
  end

  test 'turnstile validation fails when the token is expired' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = '3x0000000000000000000000000000000AA'
    visit new_book_url
    wait_for_turnstile_inputs(1, message: 'after page load')
    click_on 'Create Book'

    assert_text Cloudflare::Turnstile::Rails::ErrorMessage.default
    wait_for_turnstile_inputs(1, message: 'after expired token submit')
  end

  test 'turnstile renders two plugins when there are two forms' do
    skip "Not supported in Github actions for Ruby v#{RUBY_VERSION}" if RUBY_VERSION < '2.7.0' && ENV['CI']

    visit new2_books_url
    wait_for_turnstile_inputs(2, message: 'after page load')
    all('input[type="submit"]').each_with_index do |input, i|
      input.click
      wait_for_turnstile_inputs(2, message: "after submitting form #{i + 1}")
    end

    assert_selector 'li', text: "Title can't be blank", count: 2, wait: 5
  end

  test 'cloudflare widget does not render twice on a single form' do
    visit new_book_url
    wait_for_turnstile_inputs(1)

    assert_selector 'div.cf-turnstile', count: 1, visible: :all
    assert_selector "div.cf-turnstile input[name='cf-turnstile-response']", count: 1, visible: :all
  end

  test 'nonce is propagated from helper script to dynamically loaded Cloudflare script' do
    visit new_book_url
    wait_for_turnstile_inputs(1)

    # Get the nonce from the helper script
    helper_nonce = evaluate_script(<<~JS)
      (function() {
        var helper = document.querySelector('script[src*="cloudflare_turnstile_helper"]');
        return helper ? helper.nonce : null;
      })()
    JS

    # Get the nonce from the dynamically loaded Cloudflare script
    cloudflare_nonce = evaluate_script(<<~JS)
      (function() {
        var cf = document.querySelector('script[src*="challenges.cloudflare.com"]');
        return cf ? cf.nonce : null;
      })()
    JS

    # Both scripts should have nonces (CSP is enabled in test app)
    assert_not_nil helper_nonce, 'Helper script should have a nonce attribute'
    assert_not_nil cloudflare_nonce, 'Cloudflare script should have a nonce attribute'

    # The nonces should match (JS propagates nonce from helper to Cloudflare script)
    assert_equal helper_nonce, cloudflare_nonce,
                 'Cloudflare script nonce should match helper script nonce'
  end

  test 'turbolinks AJAX cache updates page when server returns HTML for remote form' do # rubocop:disable Metrics/BlockLength
    # This test is only relevant for Rails 6 with Turbolinks (not Rails 7+ with Turbo)
    skip 'Turbolinks not available' unless turbolinks_available?

    visit new_book_url
    wait_for_turnstile_inputs(1, message: 'after page load')

    # Verify Turbolinks AJAX cache script is loaded and listening
    listener_registered = evaluate_script(<<~JS)
      (function() {
        // The script should have set up an ajax:complete listener
        // We can verify by checking if Turbolinks.Snapshot exists (required by our script)
        return typeof Turbolinks !== 'undefined' &&
               typeof Turbolinks.Snapshot !== 'undefined' &&
               typeof Turbolinks.Snapshot.wrap === 'function';
      })()
    JS
    assert listener_registered, 'Turbolinks.Snapshot.wrap should be available for AJAX cache'

    # Simulate the AJAX cache mechanism by dispatching an ajax:complete event with HTML
    # This tests the cloudflare_turbolinks_ajax_cache.js event handler
    page_updated = evaluate_script(<<~JS)
      (function() {
        var testHtml = '<html><head></head><body>' +
          '<div class="test-marker">AJAX Cache Test Marker</div>' +
          '<form id="book_form">' +
          '<ul class="error_explanation"><li>Title cannot be blank</li></ul>' +
          '<div class="cf-turnstile" data-sitekey="test"></div>' +
          '</form></body></html>';

        var mockXhr = {
          getResponseHeader: function(name) {
            return name === 'Content-Type' ? 'text/html; charset=utf-8' : null;
          },
          response: testHtml
        };

        var event = new CustomEvent('ajax:complete', {
          bubbles: true,
          detail: [mockXhr]
        });

        document.dispatchEvent(event);

        // Give Turbolinks a moment to process
        return true;
      })()
    JS

    assert page_updated, 'AJAX complete event should be dispatched'

    # Verify the page was updated via Turbolinks restore
    assert_selector '.test-marker', text: 'AJAX Cache Test Marker', wait: 2
  end

  private

  def turbolinks_available?
    evaluate_script('typeof Turbolinks !== "undefined"')
  rescue StandardError
    false
  end

  def turnstile_selector
    "div.cf-turnstile input[name='cf-turnstile-response'][value*='DUMMY']"
  end

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
          # once we hit the desired size with nonempty values,
          # wait a moment to make sure it's stable
          stable_since ||= Time.now
          return if Time.now - stable_since > 0.5
        elsif size > count
          flunk "Expected #{count} Turnstile widgets, but found #{size}#{context}"
        else
          # reset the stability countdown if size changed
          stable_since = nil
        end
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        # DOM changed while we were checking elements; reset and retry
        stable_since = nil
      end

      flunk "Timed out waiting for #{count} Turnstile widgets; saw #{size}#{context}" if Time.now - start > timeout

      sleep 0.1
    end
  end
end
