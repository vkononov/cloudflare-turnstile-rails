module TurnstileSystemHelpers
  def wait_for_turnstile_inputs(count, timeout: 5, message: nil) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    start = Time.now
    stable_since = nil
    context = message ? " (#{message})" : ''
    size = 0

    loop do
      begin
        inputs = all("div.cf-turnstile input[name='cf-turnstile-response']", visible: :all)
        size = inputs.size

        if size == count && inputs.all? { |i| i.value.to_s.strip != '' }
          stable_since ||= Time.now
          return if Time.now - stable_since > 0.5
        elsif size > count
          flunk "Expected #{count} Turnstile widgets, but found #{size}#{context}"
        else
          stable_since = nil
        end
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        stable_since = nil
      end

      flunk "Timed out waiting for #{count} Turnstile widgets; saw #{size}#{context}" if Time.now - start > timeout

      sleep 0.1
    end
  end
end
