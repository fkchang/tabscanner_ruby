# frozen_string_literal: true

module Tabscanner
  # Base error class for all Tabscanner-specific errors
  # 
  # This class provides enhanced error handling capabilities including
  # raw response data for debugging purposes when debug mode is enabled.
  #
  # @example Basic error
  #   raise Tabscanner::Error, "Something went wrong"
  #
  # @example Error with raw response for debugging
  #   response = { status: 500, body: '{"error": "Server error"}' }
  #   raise Tabscanner::Error.new("Server error", raw_response: response)
  class Error < StandardError
    # @return [Hash, nil] Raw HTTP response data for debugging
    attr_reader :raw_response

    # Initialize error with message and optional raw response
    # @param message [String] Error message
    # @param raw_response [Hash, nil] Raw HTTP response data for debugging
    def initialize(message = nil, raw_response: nil)
      @raw_response = raw_response
      
      # Enhance message with debug info if available and debug mode enabled
      enhanced_message = build_enhanced_message(message)
      super(enhanced_message)
    end

    private

    # Build enhanced error message with debug information
    # @param base_message [String] Base error message
    # @return [String] Enhanced message with debug info if enabled
    def build_enhanced_message(base_message)
      return base_message unless Tabscanner.config.debug? && @raw_response

      debug_info = []
      
      if @raw_response.is_a?(Hash)
        debug_info << "Status: #{@raw_response[:status]}" if @raw_response[:status]
        debug_info << "Headers: #{@raw_response[:headers]}" if @raw_response[:headers]
        debug_info << "Body: #{@raw_response[:body]}" if @raw_response[:body]
      else
        debug_info << "Raw Response: #{@raw_response.inspect}"
      end

      if debug_info.any?
        "#{base_message}\n\nDebug Information:\n#{debug_info.join("\n")}"
      else
        base_message
      end
    end
  end
end