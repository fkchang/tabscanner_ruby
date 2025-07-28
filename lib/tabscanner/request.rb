# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'json'

module Tabscanner
  # Handles HTTP requests to the Tabscanner API
  # 
  # This class manages multipart form data uploads for image processing
  # and handles all HTTP communication with proper error handling.
  #
  # @example Submit a file path
  #   Request.submit_receipt('/path/to/receipt.jpg')
  #
  # @example Submit an IO stream
  #   File.open('/path/to/receipt.jpg', 'rb') do |file|
  #     Request.submit_receipt(file)
  #   end
  class Request
    # Submit a receipt image for processing
    #
    # @param file_path_or_io [String, IO] Local file path or IO stream containing image data
    # @return [String] Token for result retrieval
    # @raise [UnauthorizedError] when API key is invalid (401)
    # @raise [ValidationError] when request validation fails (422)
    # @raise [ServerError] when server errors occur (500+)
    # @raise [Error] for other API errors
    def self.submit_receipt(file_path_or_io)
      config = Tabscanner.config
      config.validate!

      # Handle file input - convert file path to IO if needed
      file_io, filename = normalize_file_input(file_path_or_io)

      # Build the connection
      conn = build_connection(config)

      # Make the request
      response = conn.post('/api/2/process') do |req|
        req.body = build_multipart_body(file_io, filename)
      end

      # Debug logging for request/response
      log_request_response('POST', '/api/2/process', response, config) if config.debug?

      handle_response(response)
    ensure
      # Close file if we opened it
      file_io&.close if file_path_or_io.is_a?(String) && file_io
    end

    private

    # Normalize file input to IO and filename
    # @param file_path_or_io [String, IO] File path or IO stream
    # @return [Array<IO, String>] IO object and filename
    def self.normalize_file_input(file_path_or_io)
      if file_path_or_io.is_a?(String)
        # File path provided
        raise Error, "File not found: #{file_path_or_io}" unless File.exist?(file_path_or_io)
        file_io = File.open(file_path_or_io, 'rb')
        filename = File.basename(file_path_or_io)
      else
        # IO stream provided
        file_io = file_path_or_io
        filename = file_io.respond_to?(:path) ? File.basename(file_io.path) : 'image'
      end

      [file_io, filename]
    end

    # Build Faraday connection with proper configuration
    # @param config [Config] Configuration instance
    # @return [Faraday::Connection] Configured connection
    def self.build_connection(config)
      base_url = config.base_url || "https://api.tabscanner.com"
      
      Faraday.new(url: base_url) do |f|
        f.request :multipart
        f.request :url_encoded
        f.adapter Faraday.default_adapter
        f.headers['apikey'] = config.api_key
        f.headers['User-Agent'] = "Tabscanner Ruby Gem #{Tabscanner::VERSION}"
      end
    end

    # Build multipart form data for file upload
    # @param file_io [IO] File IO stream
    # @param filename [String] Name of the file
    # @return [Hash] Multipart form data
    def self.build_multipart_body(file_io, filename)
      {
        image: Faraday::UploadIO.new(file_io, mime_type_for_file(filename), filename)
      }
    end

    # Determine MIME type for file
    # @param filename [String] Name of the file
    # @return [String] MIME type
    def self.mime_type_for_file(filename)
      ext = File.extname(filename).downcase
      case ext
      when '.jpg', '.jpeg'
        'image/jpeg'
      when '.png'
        'image/png'
      when '.gif'
        'image/gif'
      when '.bmp'
        'image/bmp'
      when '.tiff', '.tif'
        'image/tiff'
      else
        'image/jpeg' # Default fallback
      end
    end

    # Handle API response and extract token
    # @param response [Faraday::Response] HTTP response
    # @return [String] Token from response
    # @raise [UnauthorizedError, ValidationError, ServerError, Error] Based on status code
    def self.handle_response(response)
      raw_response = build_raw_response_data(response)
      
      case response.status
      when 200, 201
        # Success - parse and return token
        parse_success_response(response)
      when 401
        raise UnauthorizedError.new("Invalid API key or authentication failed", raw_response: raw_response)
      when 422
        error_message = parse_error_message(response) || "Request validation failed"
        raise ValidationError.new(error_message, raw_response: raw_response)
      when 500..599
        error_message = parse_error_message(response) || "Server error occurred"
        raise ServerError.new(error_message, raw_response: raw_response)
      else
        error_message = parse_error_message(response) || "Request failed with status #{response.status}"
        raise Error.new(error_message, raw_response: raw_response)
      end
    end

    # Parse successful response to extract token
    # @param response [Faraday::Response] HTTP response
    # @return [String] Token value
    def self.parse_success_response(response)
      begin
        data = JSON.parse(response.body)
        
        # Check if the API returned an error even with 200 status
        if data['success'] == false
          error_message = data['message'] || "API request failed"
          case data['code']
          when 401
            raise UnauthorizedError.new(error_message, raw_response: build_raw_response_data(response))
          when 422
            raise ValidationError.new(error_message, raw_response: build_raw_response_data(response))
          when 500..599
            raise ServerError.new(error_message, raw_response: build_raw_response_data(response))
          else
            raise Error.new(error_message, raw_response: build_raw_response_data(response))
          end
        end
        
        token = data['token'] || data['id'] || data['request_id']
        
        raise Error, "No token found in response" if token.nil? || token.empty?
        
        token
      rescue JSON::ParserError
        raise Error, "Invalid JSON response from API"
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