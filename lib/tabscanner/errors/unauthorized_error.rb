# frozen_string_literal: true

module Tabscanner
  # Raised when API authentication fails (401 status)
  class UnauthorizedError < Error; end
end