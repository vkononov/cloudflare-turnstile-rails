# Configure Content Security Policy with nonce support for testing
# This enables CSP nonces which are used by cloudflare_turnstile_tag
#
# We use report-only mode so nonces are generated and applied to script tags
# without blocking any scripts (which would break Turnstile loading).
#
# The CSP DSL was introduced in Rails 5.2, so it is skipped on older versions.
if Rails.gem_version >= Gem::Version.new('5.2')
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

    # Report-only mode: nonces are generated but CSP is not enforced
    config.content_security_policy_report_only = true
  end
end
