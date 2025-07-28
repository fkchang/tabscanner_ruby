# frozen_string_literal: true

require 'faraday'
require 'json'

module Tabscanner
  # Shared HTTP client functionality for Tabscanner API requests
  # 
  # This module provides common HTTP connection building, error handling,
  # and logging functionality used across Request, Result, and Credits classes.
  #
  # @example Include in a class
  #   class MyAPIClass
  #     extend Tabscanner::HttpClient
  #   end
  module HttpClient
    # Build Faraday connection with proper configuration
    # @param config [Config] Configuration instance
    # @param additional_headers [Hash] Additional headers to include
    # @return [Faraday::Connection] Configured connection
    def build_connection(config, additional_headers: {})
      base_url = config.base_url || "https://api.tabscanner.com"
      
      Faraday.new(url: base_url) do |f|
        f.request :url_encoded
        f.adapter Faraday.default_adapter
        f.headers['apikey'] = config.api_key
        f.headers['User-Agent'] = "Tabscanner Ruby Gem #{Tabscanner::VERSION}"
        
        # Merge any additional headers
        additional_headers.each { |key, value| f.headers[key] = value }
      end
    end

    # Build raw response data for error debugging
    # @param response [Faraday::Response] HTTP response
    # @return [Hash] Raw response data
    def build_raw_response_data(response)
      {
        status: response.status,
        headers: response.headers.to_hash,
        body: response.body
      }
    end

    # Parse error message from response
    # @param response [Faraday::Response] HTTP response  
    # @return [String, nil] Error message if available
    def parse_error_message(response)
      return nil if response.body.nil? || response.body.empty?

      begin
        data = JSON.parse(response.body)
        data['error'] || data['message'] || data['errors']&.first
      rescue JSON::ParserError
        # If JSON parsing fails, return raw body if it's short enough
        response.body.length < 200 ? response.body : nil
      end
    end

    # Handle common HTTP status codes with appropriate errors
    # @param response [Faraday::Response] HTTP response
    # @param success_handler [Proc] Block to handle successful responses
    # @return [Object] Result from success_handler
    # @raise [UnauthorizedError, ServerError, Error] Based on status code
    def handle_response_with_common_errors(response, &success_handler)
      raw_response = build_raw_response_data(response)
      
      case response.status
      when 200, 201
        success_handler.call(response)
      when 401
        raise UnauthorizedError.new("Invalid API key or authentication failed", raw_response: raw_response)
      when 500..599
        error_message = parse_error_message(response) || "Server error occurred"
        raise ServerError.new(error_message, raw_response: raw_response)
      else
        error_message = parse_error_message(response) || "Request failed with status #{response.status}"
        raise Error.new(error_message, raw_response: raw_response)
      end
    end

    # Log request and response details for debugging
    # @param method [String] HTTP method
    # @param endpoint [String] API endpoint
    # @param response [Faraday::Response] HTTP response
    # @param config [Config] Configuration instance
    def log_request_response(method, endpoint, response, config)
      logger = config.logger
      
      # Log request details
      logger.debug("HTTP Request: #{method.upcase} #{endpoint}")
      logger.debug("Request Headers: apikey=[REDACTED], User-Agent=#{response.env.request_headers['User-Agent']}")
      
      # Log response details
      logger.debug("HTTP Response: #{response.status}")
      logger.debug("Response Headers: #{response.headers.to_hash}")
      
      # Log response body (truncated if too long)
      body = response.body
      if body && body.length > 500
        logger.debug("Response Body: #{body[0..500]}... (truncated)")
      else
        logger.debug("Response Body: #{body}")
      end
    end
  end
end