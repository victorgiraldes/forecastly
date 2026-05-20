module ExternalApi
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  private

  def http_get(url, params = nil)
    @client.get(url, params) do |req|
      req.options.open_timeout = OPEN_TIMEOUT
      req.options.timeout = READ_TIMEOUT
      yield req if block_given?
    end
  rescue Faraday::Error => e
    Rails.logger.error("#{self.class.name} error: #{e.message}")
    nil
  end

  def parse_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    nil
  end
end
