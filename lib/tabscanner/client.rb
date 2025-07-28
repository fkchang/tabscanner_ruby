# frozen_string_literal: true

module Tabscanner
  # Central public interface for the Tabscanner gem
  # 
  # This module provides the main public API methods for interacting
  # with the Tabscanner service, delegating to appropriate internal classes.
  module Client
    # Submit a receipt image for OCR processing
    #
    # @param file_path_or_io [String, IO] Local file path or IO stream containing image data
    # @return [String] Token for later result retrieval
    # @raise [ConfigurationError] when configuration is invalid
    # @raise [UnauthorizedError] when API key is invalid (401)
    # @raise [ValidationError] when request validation fails (422)
    # @raise [ServerError] when server errors occur (500+)
    # @raise [Error] for other API errors
    #
    # @example Submit a file by path
    #   token = Tabscanner.submit_receipt('/path/to/receipt.jpg')
    #
    # @example Submit a file via IO stream
    #   File.open('/path/to/receipt.jpg', 'rb') do |file|
    #     token = Tabscanner.submit_receipt(file)
    #   end
    def self.submit_receipt(file_path_or_io)
      Request.submit_receipt(file_path_or_io)
    end

    # Poll for OCR processing results using a token
    #
    # @param token [String] Token from submit_receipt call
    # @param timeout [Integer] Maximum time to wait in seconds (default: 15)
    # @return [Hash] Parsed receipt data when processing is complete
    # @raise [ConfigurationError] when configuration is invalid
    # @raise [UnauthorizedError] when API key is invalid (401)
    # @raise [ValidationError] when token is invalid (422)
    # @raise [ServerError] when server errors occur (500+)
    # @raise [Error] for timeout or other API errors
    #
    # @example Poll for results with default timeout
    #   data = Tabscanner.get_result('token123')
    #
    # @example Poll for results with custom timeout
    #   data = Tabscanner.get_result('token123', timeout: 30)
    def self.get_result(token, timeout: 15)
      Result.get_result(token, timeout: timeout)
    end
  end
end