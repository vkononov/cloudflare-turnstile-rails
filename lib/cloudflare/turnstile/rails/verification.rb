require_relative 'constants/cloudflare'

module Cloudflare
  module Turnstile
    module Rails
      class VerificationResponse
        attr_reader :raw

        def initialize(raw)
          @raw = raw
        end

        def success?
          raw['success'] == true
        end

        def errors
          raw['error-codes'] || []
        end

        def action
          raw['action']
        end

        def cdata
          raw['cdata']
        end

        def challenge_ts
          raw['challenge_ts']
        end

        def hostname
          raw['hostname']
        end

        def metadata
          raw['metadata']
        end

        def to_h
          raw
        end
      end

      module Verification
        def self.verify(response:, secret: nil, remoteip: nil, idempotency_key: nil) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          raise ConfigurationError, 'Turnstile response token is missing' if response.nil? || response.strip.empty?

          config = Rails.configuration
          secret ||= config.secret_key

          raise ConfigurationError, 'Cloudflare Turnstile secret_key is not set.' if secret.nil? || secret.strip.empty?

          body = {
            'secret' => secret,
            'response' => response
          }
          body['remoteip'] = remoteip if remoteip
          body['idempotency_key'] = idempotency_key if idempotency_key

          uri = URI.parse(Cloudflare::SITE_VERIFY_URL)
          headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri.request_uri, headers)
          request.set_form_data(body)

          response = http.request(request)
          json = JSON.parse(response.body)

          VerificationResponse.new(json)
        rescue JSON::ParserError
          raise ConfigurationError, 'Unable to parse Cloudflare Turnstile verification response'
        end
      end
    end
  end
end
