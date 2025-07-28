# frozen_string_literal: true

require_relative "tabscanner/version"
require_relative "tabscanner/errors/base_error"
require_relative "tabscanner/errors/configuration_error"
require_relative "tabscanner/errors/unauthorized_error"
require_relative "tabscanner/errors/validation_error"
require_relative "tabscanner/errors/server_error"
require_relative "tabscanner/config"
require_relative "tabscanner/http_client"
require_relative "tabscanner/request"
require_relative "tabscanner/result"
require_relative "tabscanner/client"
require_relative "tabscanner/credits"

module Tabscanner
  # Submit a receipt image for OCR processing
  #
  # @param file_path_or_io [String, IO] Local file path or IO stream containing image data
  # @return [String] Token for later result retrieval
  # @see Client.submit_receipt
  def self.submit_receipt(file_path_or_io)
    Client.submit_receipt(file_path_or_io)
  end

  # Poll for OCR processing results using a token
  #
  # @param token [String] Token from submit_receipt call
  # @param timeout [Integer] Maximum time to wait in seconds (default: 15)
  # @return [Hash] Parsed receipt data when processing is complete
  # @see Client.get_result
  def self.get_result(token, timeout: 15)
    Client.get_result(token, timeout: timeout)
  end

  # Check remaining API credits for the authenticated account
  #
  # @return [Integer] Number of remaining credits
  # @see Credits.get_credits
  def self.get_credits
    Credits.get_credits
  end
end
