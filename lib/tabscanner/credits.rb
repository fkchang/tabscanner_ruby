# frozen_string_literal: true

require_relative 'http_client'
require 'json'

module Tabscanner
  # Handles credit balance retrieval from the Tabscanner API
  # 
  # This class manages HTTP requests to check the remaining API credits
  # for the authenticated account.
  #
  # @example Check remaining credits
  #   Credits.get_credits
  class Credits
    extend HttpClient
    # Get remaining API credits for the authenticated account
    #
    # @return [Integer] Number of remaining credits
    # @raise [UnauthorizedError] when API key is invalid (401)
    # @raise [ServerError] when server errors occur (500+)
    # @raise [Error] for other API errors or JSON parsing issues
    def self.get_credits
      config = Tabscanner.config
      config.validate!

      # Build the connection
      conn = build_connection(config, additional_headers: { 'Accept' => 'application/json' })

      # Make the GET request to credit endpoint
      response = conn.get('/api/credit')

      # Debug logging for request/response
      log_request_response('GET', '/api/credit', response, config) if config.debug?

      handle_response_with_common_errors(response) do |resp|
        parse_credits_response(resp)
      end
    end

    private

    # Parse credits response to extract integer credit count
    # @param response [Faraday::Response] HTTP response
    # @return [Integer] Credit count
    # @raise [Error] if response cannot be parsed as integer
    def self.parse_credits_response(response)
      begin
        # API returns a single JSON number
        credit_count = JSON.parse(response.body)
        
        # Ensure we got a numeric value
        unless credit_count.is_a?(Numeric)
          raise Error, "Invalid credit response format: expected number, got #{credit_count.class}"
        end
        
        credit_count.to_i
      rescue JSON::ParserError
        raise Error, "Invalid JSON response from API"
      end
    end

  end
end