# test/rails_test_helper.rb
require_relative 'test_helper'

require 'rails'
require 'action_controller/railtie'
require 'action_view/railtie'

require 'cloudflare/turnstile/rails'
