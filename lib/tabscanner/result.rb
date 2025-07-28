# frozen_string_literal: true

require 'faraday'
require 'json'

module Tabscanner
  # Handles polling for OCR processing results
  # 
  # This class manages the polling logic to retrieve processing results
  # from the Tabscanner API using a token, with retry logic and timeout handling.
  #
  # @example Poll for results with default timeout
  #   Result.get_result('token123')
  #
  # @example Poll for results with custom timeout
  #   Result.get_result('token123', timeout: 30)
  class Result
    # Poll for OCR processing results using a token
    #
    # @param token [String] Token from submit_receipt call
    # @param timeout [Integer] Maximum time to wait in seconds (default: 15)
    # @return [Hash] Parsed receipt data when processing is complete
    # @raise [UnauthorizedError] when API key is invalid (401)
    # @raise [ValidationError] when token is invalid (422)
    # @raise [ServerError] when server errors occur (500+)
    # @raise [Error] for timeout or other API errors
    def self.get_result(token, timeout: 15)
      config = Tabscanner.config
      config.validate!

      start_time = Time.now
      conn = build_connection(config)

      config.logger.debug("Starting result polling for token: #{token} (timeout: #{timeout}s)") if config.debug?

      loop do
        # Check timeout
        elapsed = Time.now - start_time
        if elapsed >= timeout
          raise Error, "Timeout waiting for result after #{timeout} seconds"
        end

        # Make GET request to result endpoint
        response = conn.get("/api/2/result/#{token}")
        
        # Debug logging for request/response
        log_request_response('GET', "/api/2/result/#{token}", response, config) if config.debug?
        
        result = handle_response(response)

        # Check status in response
        case result['status']
        when 'complete', 'completed', 'success'
          config.logger.debug("Result ready for token: #{token}") if config.debug?
          return extract_result_data(result)
        when 'processing', 'pending', 'in_progress'
          # Wait 1 second before next poll
          config.logger.debug("Result still processing for token: #{token}, waiting 1s...") if config.debug?
          sleep 1
          next
        when 'failed', 'error'
          error_message = result['error'] || result['message'] || 'Processing failed'
          config.logger.debug("Result failed for token: #{token} - #{error_message}") if config.debug?
          raise Error, error_message
        else
          # Unknown status - treat as error
          config.logger.debug("Unknown status for token: #{token} - #{result['status']}") if config.debug?
          raise Error, "Unknown processing status: #{result['status']}"
        end
      end
    end

    private

    # Build Faraday connection with proper configuration
    # @param config [Config] Configuration instance
    # @return [Faraday::Connection] Configured connection
    def self.build_connection(config)
      base_url = config.base_url || "https://api.tabscanner.com"
      
      Faraday.new(url: base_url) do |f|
        f.request :url_encoded
        f.adapter Faraday.default_adapter
        f.headers['Authorization'] = "Bearer #{config.api_key}"
        f.headers['User-Agent'] = "Tabscanner Ruby Gem #{Tabscanner::VERSION}"
        f.headers['Accept'] = 'application/json'
      end
    end

    # Handle API response
    # @param response [Faraday::Response] HTTP response
    # @return [Hash] Parsed JSON response
    # @raise [UnauthorizedError, ValidationError, ServerError, Error] Based on status code
    def self.handle_response(response)
      raw_response = build_raw_response_data(response)
      
      case response.status
      when 200, 201
        # Success - parse and return data
        parse_json_response(response)
      when 401
        raise UnauthorizedError.new("Invalid API key or authentication failed", raw_response: raw_response)
      when 422
        error_message = parse_error_message(response) || "Invalid token or request"
        raise ValidationError.new(error_message, raw_response: raw_response)
      when 500..599
        error_message = parse_error_message(response) || "Server error occurred"
        raise ServerError.new(error_message, raw_response: raw_response)
      else
        error_message = parse_error_message(response) || "Request failed with status #{response.status}"
        raise Error.new(error_message, raw_response: raw_response)
      end
    end

    # Parse JSON response body
    # @param response [Faraday::Response] HTTP response
    # @return [Hash] Parsed JSON data
    # @raise [Error] if JSON parsing fails
    def self.parse_json_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "Invalid JSON response from API"
    end

    # Extract result data from complete response
    # @param result [Hash] Parsed response data
    # @return [Hash] Receipt data
    def self.extract_result_data(result)
      # Return the full result hash - the actual data structure will depend on the API
      # Common patterns: result['data'], result['receipt'], or the full result
      if result.key?('data')
        result['data']
      elsif result.key?('receipt')
        result['receipt']
      else
        # Return the full result excluding status metadata
        result.reject { |k, _| %w[status message timestamp id].include?(k) }
      end
    end

    # Parse error message from response
    # @param response [Faraday::Response] HTTP response  
    # @return [String, nil] Error message if available
    def self.parse_error_message(response)
      return nil if response.body.nil? || response.body.empty?

      begin
        data = JSON.parse(response.body)
        data['error'] || data['message'] || data['errors']&.first
      rescue JSON::ParserError
        # If JSON parsing fails, return raw body if it's short enough
        response.body.length < 200 ? response.body : nil
      end
    end

    # Build raw response data for error debugging
    # @param response [Faraday::Response] HTTP response
    # @return [Hash] Raw response data
    def self.build_raw_response_data(response)
      {
        status: response.status,
        headers: response.headers.to_hash,
        body: response.body
      }
    end

    # Log request and response details for debugging
    # @param method [String] HTTP method
    # @param endpoint [String] API endpoint
    # @param response [Faraday::Response] HTTP response
    # @param config [Config] Configuration instance
    def self.log_request_response(method, endpoint, response, config)
      logger = config.logger
      
      # Log request details
      logger.debug("HTTP Request: #{method.upcase} #{endpoint}")
      logger.debug("Request Headers: Authorization=Bearer [REDACTED], User-Agent=#{response.env.request_headers['User-Agent']}")
      
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