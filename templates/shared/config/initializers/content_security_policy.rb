# Configure Content Security Policy with nonce support for testing
# This enables CSP nonces which are used by cloudflare_turnstile_tag
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self, 'https://challenges.cloudflare.com'
    policy.frame_src   :self, 'https://challenges.cloudflare.com'
  end

  # Generate nonces for script tags
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
