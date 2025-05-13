require 'test_helper'

class BooksControllerTest < ActionDispatch::IntegrationTest
  test 'throws an exception when secret key is empty' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = nil

    assert_raises ActionView::Template::Error, 'Cloudflare Turnstile secret_key is not set' do
      get new_book_url
    end
  end

  test 'throws an exception when site key is nil' do
    Cloudflare::Turnstile::Rails.configuration.site_key = nil

    assert_raises ActionView::Template::Error, 'Cloudflare Turnstile site_key is not set' do
      get new_book_url
    end
  end
end
