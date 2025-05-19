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
        def self.verify(response: nil, secret: nil, remoteip: nil, idempotency_key: nil) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          if response.nil? || response.strip.empty?
            unless ::Rails.env.test? && Rails.configuration.auto_populate_response_in_test_env
              raise ConfigurationError, ErrorMessage.for(ErrorCode::MISSING_INPUT_RESPONSE)
            end

            response = 'dummy-response'

          end

          secret ||= Rails.configuration.secret_key
          if secret.nil? || secret.strip.empty?
            raise ConfigurationError, ErrorMessage.for(ErrorCode::MISSING_INPUT_SECRET)
          end

          body = { 'secret' => secret, 'response' => response }
          body['remoteip'] = remoteip if remoteip
          body['idempotency_key'] = idempotency_key if idempotency_key

          uri = URI.parse(Cloudflare::SITE_VERIFY_URL)
          request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type': 'application/x-www-form-urlencoded')
          request.set_form_data(body)

          res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
          begin
            json = JSON.parse(res.body)
          rescue JSON::ParserError
            raise ConfigurationError, ErrorMessage.for(ErrorCode::INTERNAL_ERROR)
          end

          VerificationResponse.new(json)
        end
      end
    end
  end
end
