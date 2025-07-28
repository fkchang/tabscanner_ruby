# frozen_string_literal: true

module Tabscanner
  # Raised when API request validation fails (422 status)
  class ValidationError < Error; end
end