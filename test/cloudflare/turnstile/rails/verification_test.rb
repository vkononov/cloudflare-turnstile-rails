require 'test_helper'

require 'webmock/minitest'

require 'cloudflare/turnstile/rails/constants/cloudflare'
require 'cloudflare/turnstile/rails/verification'

class VerificationResponseTest < Minitest::Test
  def setup
    @raw = {
      'success' => true,
      'error-codes' => %w[foo bar],
      'action' => 'test_action',
      'cdata' => 'custom-data',
      'challenge_ts' => '2022-10-06T00:07:23.274Z',
      'hostname' => 'example.com',
      'metadata' => { 'ephemeral_id' => 'x:123' }
    }
    @resp = Cloudflare::Turnstile::Rails::VerificationResponse.new(@raw)
  end

  def test_success?
    assert_predicate @resp, :success?
  end

  def test_errors
    assert_equal %w[foo bar], @resp.errors
  end

  def test_action_cdata_ts_hostname_metadata
    assert_equal 'test_action', @resp.action
    assert_equal 'custom-data', @resp.cdata
    assert_equal '2022-10-06T00:07:23.274Z', @resp.challenge_ts
    assert_equal 'example.com', @resp.hostname
    assert_equal({ 'ephemeral_id' => 'x:123' }, @resp.metadata)
  end

  def test_to_h_returns_raw
    assert_same @raw, @resp.to_h
  end

  def test_errors_empty_when_none
    empty = Cloudflare::Turnstile::Rails::VerificationResponse.new({})

    assert_empty empty.errors
  end
end

class VerificationTest < Minitest::Test
  def setup
    @url           = Cloudflare::Turnstile::Rails::Cloudflare::SITE_VERIFY_URL
    @valid_secret  = 'sk_test'
    @valid_token   = 'tok_test'
    # ensure Rails.configuration.secret_key
    Cloudflare::Turnstile::Rails.configure do |c|
      c.secret_key = @valid_secret
    end
  end

  def stub_verify(opts = {})
    status = opts.delete(:status) || 200

    stub_request(:post, @url)
      .with(headers: { 'Content-Type' => 'application/x-www-form-urlencoded' })
      .to_return(
        status: status,
        body: opts.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def test_missing_response_raises
    err = assert_raises(Cloudflare::Turnstile::Rails::ConfigurationError) do
      Cloudflare::Turnstile::Rails::Verification.verify(response: '')
    end
    assert_match(/response token is missing/, err.message)
  end

  def test_missing_secret_raises
    Cloudflare::Turnstile::Rails.configuration.secret_key = nil
    err = assert_raises(Cloudflare::Turnstile::Rails::ConfigurationError) do
      Cloudflare::Turnstile::Rails::Verification.verify(response: 'token')
    end
    assert_match(/secret_key is not set/, err.message)
  end

  def test_successful_verification
    stub_verify('success' => true)
    resp = Cloudflare::Turnstile::Rails::Verification.verify(
      response: @valid_token
    )

    assert_kind_of Cloudflare::Turnstile::Rails::VerificationResponse, resp
    assert_predicate resp, :success?
    assert_empty resp.errors
  end

  def test_verification_with_error_codes
    stub_verify('success' => false, 'error-codes' => ['timeout-or-duplicate'])
    resp = Cloudflare::Turnstile::Rails::Verification.verify(
      response: @valid_token
    )

    refute_predicate resp, :success?
    assert_equal ['timeout-or-duplicate'], resp.errors
  end

  def test_remoteip_and_idempotency_key_submitted
    stub_request(:post, @url).with do |req|
      body = URI.decode_www_form(req.body).to_h
      body['remoteip'] == '1.2.3.4' &&
        body['idempotency_key'] =~ /^[0-9a-f-]{36}$/ &&
        body['secret'] == @valid_secret &&
        body['response'] == @valid_token
    end
      .to_return(body: { 'success' => true }.to_json)

    resp = Cloudflare::Turnstile::Rails::Verification.verify(
      response: @valid_token, remoteip: '1.2.3.4', idempotency_key: SecureRandom.uuid
    )

    assert_predicate resp, :success?
  end

  def test_json_parse_error_raises
    stub_request(:post, @url).to_return(body: 'not json', status: 200)
    err = assert_raises(Cloudflare::Turnstile::Rails::ConfigurationError) do
      Cloudflare::Turnstile::Rails::Verification.verify(response: @valid_token)
    end
    assert_match(/Unable to parse/, err.message)
  end
end
