require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  BROWSER = ENV.fetch('BROWSER', 'chrome').to_sym
  driven_by :selenium, using: :"headless_#{BROWSER}", screen_size: [1400, 1400]
end
