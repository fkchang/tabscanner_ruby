#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Check remaining API credits
#
# This example demonstrates how to check your remaining API credits
# for the Tabscanner service. This is useful for monitoring usage
# and staying within the 200 free plan limit.

require_relative '../lib/tabscanner'
require 'logger'

# Configure the Tabscanner gem
Tabscanner.configure do |config|
  # Set your API key from environment variable or directly
  config.api_key = ENV['TABSCANNER_API_KEY'] || 'your-api-key-here'
  
  # Optional: Enable debug mode for detailed logging
  config.debug = ENV['TABSCANNER_DEBUG'] == 'true'
  
  # Optional: Set custom base URL if needed
  # config.base_url = 'https://custom.api.example.com'
end

begin
  puts "Checking remaining API credits..."
  
  # Check credits
  credits = Tabscanner.get_credits
  
  puts "✅ Remaining credits: #{credits}"
  
  # Provide usage guidance based on credit count
  if credits == 0
    puts "⚠️  Warning: You have no credits remaining!"
    puts "   Please upgrade your plan or wait for credits to reset."
  elsif credits < 10
    puts "⚠️  Warning: Low credit balance (#{credits} remaining)"
    puts "   Consider upgrading your plan or monitoring usage carefully."
  elsif credits < 50
    puts "ℹ️  Credit balance is getting low (#{credits} remaining)"
  else
    puts "✨ You have plenty of credits available!"
  end

rescue Tabscanner::ConfigurationError => e
  puts "❌ Configuration error: #{e.message}"
  puts "   Please make sure TABSCANNER_API_KEY is set in your environment."
  puts "   Example: export TABSCANNER_API_KEY='your-actual-api-key'"
  exit 1

rescue Tabscanner::UnauthorizedError => e
  puts "❌ Authentication failed: #{e.message}"
  puts "   Please check that your API key is valid and active."
  puts "   You can get your API key from the Tabscanner dashboard."
  exit 1

rescue Tabscanner::ServerError => e
  puts "❌ Server error: #{e.message}"
  puts "   The Tabscanner service is experiencing issues. Please try again later."
  exit 1

rescue Tabscanner::Error => e
  puts "❌ Unexpected error: #{e.message}"
  if Tabscanner.config.debug?
    puts "\nDebug Information:"
    puts e.raw_response.inspect if e.respond_to?(:raw_response)
  end
  exit 1

rescue StandardError => e
  puts "❌ Unexpected system error: #{e.message}"
  puts "   #{e.class}: #{e.backtrace.first}"
  exit 1
end