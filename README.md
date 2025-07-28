# Tabscanner

A Ruby gem for processing receipt images using the Tabscanner API. Extract structured data from receipt images with just a few lines of code.

## Features

- 📸 **Image Processing**: Submit receipt images via file path or IO stream
- 🔄 **Automatic Polling**: Built-in polling for processing results with timeout handling
- 🛡️ **Error Handling**: Comprehensive error handling with detailed debug information
- 🔧 **Configurable**: Environment variables and programmatic configuration
- 🐛 **Debug Support**: Optional debug logging for troubleshooting
- ⚡ **Simple API**: Complete workflow in under 10 lines of code

## Installation

### Using Bundler

Add this line to your application's Gemfile:

```ruby
gem 'tabscanner'
```

Then execute:

```bash
bundle install
```

### Manual Installation

Install the gem directly:

```bash
gem install tabscanner
```

## Quick Start

Here's a complete example that processes a receipt in under 10 lines:

```ruby
require 'tabscanner'

# Configure
Tabscanner.configure do |config|
  config.api_key = 'your_api_key_here'
end

# Process receipt
token = Tabscanner.submit_receipt('receipt.jpg')
result = Tabscanner.get_result(token)

puts "Merchant: #{result['merchant']}"
puts "Total: $#{result['total']}"
```

## Configuration

### Environment Variables

The simplest way to configure the gem is using environment variables:

```bash
export TABSCANNER_API_KEY=your_api_key_here
export TABSCANNER_REGION=us  # Optional, defaults to 'us'
export TABSCANNER_BASE_URL=https://custom.api.url  # Optional, for staging/testing
export TABSCANNER_DEBUG=true  # Optional, enables debug logging
```

### Programmatic Configuration

```ruby
Tabscanner.configure do |config|
  config.api_key = 'your_api_key_here'
  config.region = 'us'  # Optional
  config.base_url = 'https://api.tabscanner.com'  # Optional
  config.debug = false  # Optional, enables debug logging
  config.logger = Logger.new(STDOUT)  # Optional, custom logger
end
```

### Configuration Examples

#### Production Configuration
```ruby
Tabscanner.configure do |config|
  config.api_key = ENV['TABSCANNER_API_KEY']
  config.region = 'us'
  config.debug = false
end
```

#### Development Configuration
```ruby
Tabscanner.configure do |config|
  config.api_key = ENV['TABSCANNER_API_KEY']
  config.region = 'us'
  config.debug = true
  config.logger = Logger.new(STDOUT)
end
```

#### Staging Configuration
```ruby
Tabscanner.configure do |config|
  config.api_key = ENV['TABSCANNER_STAGING_API_KEY']
  config.region = 'us'
  config.base_url = 'https://staging.tabscanner.com'
  config.debug = true
end
```

## Usage

### Basic Usage

#### Submit a Receipt Image

```ruby
# From file path
token = Tabscanner.submit_receipt('/path/to/receipt.jpg')

# From IO stream
File.open('/path/to/receipt.jpg', 'rb') do |file|
  token = Tabscanner.submit_receipt(file)
end

# From uploaded file (Rails example)
token = Tabscanner.submit_receipt(params[:receipt_file])
```

#### Get Processing Results

```ruby
# With default timeout (15 seconds)
result = Tabscanner.get_result(token)

# With custom timeout
result = Tabscanner.get_result(token, timeout: 30)
```

### Complete Workflow Example

```ruby
require 'tabscanner'

# Configure once
Tabscanner.configure do |config|
  config.api_key = ENV['TABSCANNER_API_KEY']
  config.debug = Rails.env.development?
end

# Process multiple receipts
receipt_files = Dir['receipts/*.jpg']

receipt_files.each do |file_path|
  begin
    # Submit for processing
    puts "Processing #{file_path}..."
    token = Tabscanner.submit_receipt(file_path)
    
    # Get results
    result = Tabscanner.get_result(token, timeout: 30)
    
    # Use the data
    puts "✅ #{File.basename(file_path)}"
    puts "   Merchant: #{result['merchant']}"
    puts "   Total: $#{result['total']}"
    puts "   Date: #{result['date']}"
    puts "   Items: #{result['items']&.count || 0}"
    puts
    
  rescue => e
    puts "❌ Error processing #{file_path}: #{e.message}"
  end
end
```

### Ruby on Rails Integration

```ruby
class ReceiptsController < ApplicationController
  def create
    receipt_file = params[:receipt_file]
    
    begin
      # Submit receipt for processing
      token = Tabscanner.submit_receipt(receipt_file)
      
      # Store token for later retrieval
      receipt = Receipt.create!(
        user: current_user,
        token: token,
        status: 'processing',
        filename: receipt_file.original_filename
      )
      
      # Start background job to poll for results
      ProcessReceiptJob.perform_later(receipt.id)
      
      render json: { status: 'submitted', receipt_id: receipt.id }
      
    rescue Tabscanner::ValidationError => e
      render json: { error: "Invalid receipt: #{e.message}" }, status: 422
    rescue Tabscanner::UnauthorizedError => e
      render json: { error: "API authentication failed" }, status: 401
    rescue => e
      render json: { error: "Processing failed: #{e.message}" }, status: 500
    end
  end
end

# Background job
class ProcessReceiptJob < ApplicationJob
  def perform(receipt_id)
    receipt = Receipt.find(receipt_id)
    
    begin
      result = Tabscanner.get_result(receipt.token, timeout: 60)
      
      receipt.update!(
        status: 'completed',
        merchant: result['merchant'],
        total: result['total'],
        date: result['date'],
        raw_data: result
      )
      
    rescue Tabscanner::Error => e
      receipt.update!(status: 'failed', error_message: e.message)
    end
  end
end
```

## Error Handling

The gem provides specific error classes for different types of failures:

### Error Types

- `Tabscanner::ConfigurationError` - Invalid or missing configuration
- `Tabscanner::UnauthorizedError` - Authentication failures (401)
- `Tabscanner::ValidationError` - Request validation failures (422)
- `Tabscanner::ServerError` - Server errors (500+)
- `Tabscanner::Error` - Base error class for other failures

### Error Handling Examples

#### Basic Error Handling

```ruby
begin
  token = Tabscanner.submit_receipt('receipt.jpg')
  result = Tabscanner.get_result(token)
rescue Tabscanner::ConfigurationError => e
  puts "Configuration problem: #{e.message}"
rescue Tabscanner::UnauthorizedError => e
  puts "Authentication failed: #{e.message}"
rescue Tabscanner::ValidationError => e
  puts "Invalid request: #{e.message}"
rescue Tabscanner::ServerError => e
  puts "Server error: #{e.message}"
rescue Tabscanner::Error => e
  puts "General error: #{e.message}"
end
```

#### Specific Error Scenarios

```ruby
# Handle configuration errors
begin
  Tabscanner.submit_receipt('receipt.jpg')
rescue Tabscanner::ConfigurationError => e
  # API key not set or invalid
  puts "Please set TABSCANNER_API_KEY environment variable"
  return
end

# Handle authentication errors
begin
  token = Tabscanner.submit_receipt('receipt.jpg')
rescue Tabscanner::UnauthorizedError => e
  # Invalid API key or expired
  puts "Please check your API key: #{e.message}"
  return
end

# Handle validation errors
begin
  token = Tabscanner.submit_receipt('invalid-file.txt')
rescue Tabscanner::ValidationError => e
  # Invalid file format or corrupted image
  puts "Invalid image file: #{e.message}"
  return
end

# Handle timeout errors
begin
  result = Tabscanner.get_result(token, timeout: 5)
rescue Tabscanner::Error => e
  if e.message.include?('Timeout')
    puts "Processing is taking longer than expected, try again later"
  else
    puts "Unexpected error: #{e.message}"
  end
end
```

#### Advanced Error Handling with Debug Information

When debug mode is enabled, errors include additional debugging information:

```ruby
Tabscanner.configure do |config|
  config.api_key = 'your_key'
  config.debug = true  # Enable debug mode
end

begin
  result = Tabscanner.get_result('invalid_token')
rescue Tabscanner::ValidationError => e
  puts "Error: #{e.message}"
  
  # Access raw response data for debugging
  if e.raw_response
    puts "HTTP Status: #{e.raw_response[:status]}"
    puts "Response Body: #{e.raw_response[:body]}"
    puts "Response Headers: #{e.raw_response[:headers]}"
  end
end
```

#### Retry Logic Example

```ruby
def process_receipt_with_retry(file_path, max_retries: 3)
  retries = 0
  
  begin
    token = Tabscanner.submit_receipt(file_path)
    result = Tabscanner.get_result(token)
    return result
    
  rescue Tabscanner::ServerError => e
    retries += 1
    if retries <= max_retries
      puts "Server error, retrying (#{retries}/#{max_retries})..."
      sleep(2 ** retries)  # Exponential backoff
      retry
    else
      raise e
    end
    
  rescue Tabscanner::UnauthorizedError, Tabscanner::ValidationError => e
    # Don't retry these errors
    raise e
  end
end
```

## Debug Mode

Enable debug mode to get detailed logging of HTTP requests and responses:

### Environment Variable

```bash
export TABSCANNER_DEBUG=true
```

### Programmatic Configuration

```ruby
Tabscanner.configure do |config|
  config.api_key = 'your_key'
  config.debug = true
  config.logger = Logger.new(STDOUT)  # Optional: custom logger
end
```

### Debug Output Example

When debug mode is enabled, you'll see detailed logs:

```
[2023-07-28 10:30:15] DEBUG -- Tabscanner: Starting result polling for token: abc123 (timeout: 15s)
[2023-07-28 10:30:15] DEBUG -- Tabscanner: HTTP Request: GET result/abc123
[2023-07-28 10:30:15] DEBUG -- Tabscanner: Request Headers: Authorization=Bearer [REDACTED], User-Agent=Tabscanner Ruby Gem 1.0.0
[2023-07-28 10:30:16] DEBUG -- Tabscanner: HTTP Response: 200
[2023-07-28 10:30:16] DEBUG -- Tabscanner: Response Headers: {"content-type"=>["application/json"]}
[2023-07-28 10:30:16] DEBUG -- Tabscanner: Response Body: {"status":"processing"}
[2023-07-28 10:30:16] DEBUG -- Tabscanner: Result still processing for token: abc123, waiting 1s...
```

## API Reference

### Configuration Methods

```ruby
# Configure the gem
Tabscanner.configure do |config|
  config.api_key = 'string'      # Required: Your API key
  config.region = 'string'       # Optional: API region (default: 'us')
  config.base_url = 'string'     # Optional: Custom API base URL
  config.debug = boolean         # Optional: Enable debug logging (default: false)
  config.logger = Logger         # Optional: Custom logger instance
end

# Access current configuration
Tabscanner.config

# Validate configuration
Tabscanner.config.validate!
```

### Core Methods

```ruby
# Submit a receipt for processing
# @param file_path_or_io [String, IO] File path or IO stream
# @return [String] Token for result retrieval
token = Tabscanner.submit_receipt(file_path_or_io)

# Get processing results
# @param token [String] Token from submit_receipt
# @param timeout [Integer] Maximum wait time in seconds (default: 15)
# @return [Hash] Parsed receipt data
result = Tabscanner.get_result(token, timeout: 30)
```

### Response Format

The `get_result` method returns a hash with the parsed receipt data:

```ruby
{
  "merchant" => "Coffee Shop",
  "total" => 15.99,
  "subtotal" => 14.50,
  "tax" => 1.49,
  "date" => "2023-07-28",
  "time" => "14:30:00",
  "items" => [
    {
      "name" => "Latte",
      "price" => 4.50,
      "quantity" => 1
    },
    {
      "name" => "Sandwich",
      "price" => 10.00,
      "quantity" => 1
    }
  ],
  "payment_method" => "Credit Card",
  "currency" => "USD"
}
```

## Examples

### Simple Script Example (Under 10 Lines)

Create a file `process_receipt.rb`:

```ruby
#!/usr/bin/env ruby
require 'tabscanner'

Tabscanner.configure { |c| c.api_key = ENV['TABSCANNER_API_KEY'] }

token = Tabscanner.submit_receipt(ARGV[0])
result = Tabscanner.get_result(token)

puts "Merchant: #{result['merchant']}"
puts "Total: $#{result['total']}"
puts "Items: #{result['items']&.count || 0}"
```

Usage:
```bash
ruby process_receipt.rb receipt.jpg
```

### Batch Processing Example

```ruby
require 'tabscanner'

Tabscanner.configure do |config|
  config.api_key = ENV['TABSCANNER_API_KEY']
  config.debug = true
end

receipts_dir = 'receipts'
results = []

Dir[File.join(receipts_dir, '*.{jpg,jpeg,png}')].each do |file_path|
  puts "Processing #{File.basename(file_path)}..."
  
  begin
    token = Tabscanner.submit_receipt(file_path)
    result = Tabscanner.get_result(token, timeout: 30)
    
    results << {
      file: File.basename(file_path),
      merchant: result['merchant'],
      total: result['total'],
      date: result['date']
    }
    
    puts "✅ Success: #{result['merchant']} - $#{result['total']}"
    
  rescue => e
    puts "❌ Error: #{e.message}"
  end
end

# Save results to CSV
require 'csv'
CSV.open('receipt_results.csv', 'w') do |csv|
  csv << ['File', 'Merchant', 'Total', 'Date']
  results.each { |r| csv << [r[:file], r[:merchant], r[:total], r[:date]] }
end

puts "\nProcessed #{results.count} receipts successfully"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fkchang/tabscanner.
