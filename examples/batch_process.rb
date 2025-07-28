#!/usr/bin/env ruby
# Batch process multiple receipts and save to CSV
require_relative '../lib/tabscanner'
require 'csv'

Tabscanner.configure do |config|
  config.api_key = ENV['TABSCANNER_API_KEY']
  config.debug = ENV['DEBUG'] == 'true'
end

receipts_dir = ARGV[0] || 'receipts'
results = []

puts "Processing receipts from #{receipts_dir}..."

Dir[File.join(receipts_dir, '*.{jpg,jpeg,png}')].each do |file_path|
  puts "Processing #{File.basename(file_path)}..."
  
  begin
    token = Tabscanner.submit_receipt(file_path)
    result = Tabscanner.get_result(token, timeout: 30)
    
    results << {
      file: File.basename(file_path),
      merchant: result['merchant'],
      total: result['total'],
      date: result['date'],
      items_count: result['items']&.count || 0
    }
    
    puts "✅ Success: #{result['merchant']} - $#{result['total']}"
    
  rescue Tabscanner::ConfigurationError => e
    puts "❌ Configuration error: #{e.message}"
    puts "Please set TABSCANNER_API_KEY environment variable"
    exit 1
  rescue Tabscanner::ValidationError => e
    puts "❌ Invalid file #{File.basename(file_path)}: #{e.message}"
  rescue => e
    puts "❌ Error processing #{File.basename(file_path)}: #{e.message}"
  end
end

if results.any?
  # Save results to CSV
  output_file = 'receipt_results.csv'
  CSV.open(output_file, 'w') do |csv|
    csv << ['File', 'Merchant', 'Total', 'Date', 'Items Count']
    results.each { |r| csv << [r[:file], r[:merchant], r[:total], r[:date], r[:items_count]] }
  end

  puts "\n✅ Processed #{results.count} receipts successfully"
  puts "📄 Results saved to #{output_file}"
else
  puts "\n❌ No receipts processed successfully"
end