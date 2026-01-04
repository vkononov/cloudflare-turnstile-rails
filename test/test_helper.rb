# test/test_helper.rb
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'bundler/setup'
require 'logger'

require 'minitest/autorun'
require 'minitest/mock'
