require 'uri'
require 'capybara/selenium/driver'

# Capybara 3.40 resets a Chrome session with
# `Storage.clearDataForOrigin(origin: '*')`, which Chrome 158 rejects with
# "invalid argument: * is not a valid URL", failing every system test in
# teardown (teamcapybara/capybara#2865). When Chrome rejects the wildcard,
# clear every cookie and the local storage of each origin the tab visited
# instead, which is what the wildcard call used to cover.
module ChromeStorageReset
  private

  def execute_cdp(cmd, params = {})
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError
    raise unless cmd == 'Storage.clearDataForOrigin' && params[:origin] == '*'

    super('Network.clearBrowserCookies')
    return unless params[:storageTypes].to_s.include?('local_storage')

    visited_origins.each do |origin|
      super('Storage.clearDataForOrigin', origin: origin, storageTypes: 'local_storage')
    end
  end

  def visited_origins
    entries = execute_cdp('Page.getNavigationHistory')['entries']
    entries.map { |entry| http_origin(entry['url']) }.compact.uniq
  end

  def http_origin(url)
    uri = URI.parse(url.to_s)
    return unless %w[http https].include?(uri.scheme) && uri.host

    port = uri.port == uri.default_port ? '' : ":#{uri.port}"
    "#{uri.scheme}://#{uri.host}#{port}"
  rescue URI::InvalidURIError
    nil
  end
end

if defined?(Capybara::Selenium::Driver::ChromeDriver) &&
   Capybara::Selenium::Driver::ChromeDriver.private_method_defined?(:execute_cdp)
  Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeStorageReset)
end
