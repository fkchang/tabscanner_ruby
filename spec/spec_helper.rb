# frozen_string_literal: true

# Start SimpleCov for coverage analysis
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/examples/'
  minimum_coverage 90
  coverage_dir 'coverage'
end

require "tabscanner"
require "vcr"
require "webmock/rspec"
require "tempfile"
require "stringio"

# Configure VCR for recording HTTP interactions
VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  
  
  
  # Filter sensitive data from cassettes
  config.filter_sensitive_data('<API_KEY>') { ENV['TABSCANNER_API_KEY'] }
  config.filter_sensitive_data('<API_KEY>') do |interaction|
    interaction.request.headers['apikey']&.first
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset configuration before each test
  config.before(:each) do
    Tabscanner::Config.reset!
  end
end
