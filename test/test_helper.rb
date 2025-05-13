$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

# Load Rails and Railtie support for controllers and views
require 'logger'
require 'rails'
require 'action_controller/railtie'
require 'action_view/railtie'

require 'cloudflare/turnstile/rails'

require 'minitest/autorun'
