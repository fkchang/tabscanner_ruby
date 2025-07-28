#!/usr/bin/env ruby
# Simple receipt processing script - under 10 lines of code
require_relative '../lib/tabscanner'

Tabscanner.configure { |c| c.api_key = ENV['TABSCANNER_API_KEY'] }

token = Tabscanner.submit_receipt(ARGV[0])
result = Tabscanner.get_result(token)

puts "Merchant: #{result['merchant']}"
puts "Total: $#{result['total']}"
puts "Items: #{result['items']&.count || 0}"