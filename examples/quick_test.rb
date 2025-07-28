#!/usr/bin/env ruby
# Quick test script to verify gem functionality
require_relative '../lib/tabscanner'

# Test configuration
begin
  Tabscanner.configure do |config|
    config.api_key = ENV['TABSCANNER_API_KEY'] || 'test_key'
    config.debug = true
  end
  
  puts "✅ Configuration successful"
  puts "   API Key: #{Tabscanner.config.api_key ? '[SET]' : '[NOT SET]'}"
  puts "   Region: #{Tabscanner.config.region}"
  puts "   Debug: #{Tabscanner.config.debug?}"
rescue => e
  puts "❌ Configuration failed: #{e.message}"
  exit 1
end

# Test validation
begin
  Tabscanner.config.validate!
  puts "✅ Configuration validation passed"
rescue Tabscanner::ConfigurationError => e
  puts "❌ Configuration validation failed: #{e.message}"
  puts "   Please set TABSCANNER_API_KEY environment variable"
  exit 1
end

puts "\n🎉 Gem is properly configured and ready to use!"
puts "\nTo process a receipt:"
puts "  ruby examples/process_receipt.rb path/to/receipt.jpg"
puts "\nTo batch process receipts:"
puts "  ruby examples/batch_process.rb receipts_directory"