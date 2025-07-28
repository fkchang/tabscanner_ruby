# Technical Architecture Document: Tabscanner Ruby Gem

## Overview

This document outlines the system architecture for the Tabscanner Ruby Gem. The gem serves as a wrapper for the Tabscanner OCR API, enabling Ruby developers to easily submit receipts and retrieve structured OCR results.

## Architecture Goals

* Simple and clean gem structure with separation of concerns
* Pluggable HTTP layer for testing/mocking
* Minimal external dependencies
* Easy to read, extend, and test

## Module Structure

```
tabscanner/
├── version.rb
├── config.rb
├── client.rb
├── request.rb
├── result.rb
├── errors/
│   ├── base_error.rb
│   ├── unauthorized_error.rb
│   ├── validation_error.rb
│   └── server_error.rb
└── spec/
    ├── spec_helper.rb
    ├── client_spec.rb
    ├── result_spec.rb
    └── cassettes/ (for VCR)
```

## Components

### 1. Configuration

* Stores `api_key`, `region`, `base_url`
* Default values come from ENV
* Singleton pattern with `Tabscanner.configure` block

### 2. Client

* Central public interface
* Methods: `submit_receipt`, `get_result`
* Delegates to `Request` and `Result`

### 3. Request

* Handles multipart form data for image uploads
* Manages headers and endpoint logic
* Raises wrapped errors on failure

### 4. Result

* Polls API for status updates using token
* Supports timeout and retry interval
* Returns parsed JSON

### 5. Errors

* Base error class: `Tabscanner::Error`
* Subclasses for HTTP status handling:

  * `UnauthorizedError`
  * `ValidationError`
  * `ServerError`

### 6. Logging (Optional)

* Controlled via config `debug = true`
* Outputs HTTP request/response if enabled

## HTTP Adapter

* Use `Faraday` for simplicity and middleware support
* Faraday adapter easily swapped/mocked in tests

## Testing

* **Framework:** RSpec
* **API mocking:** VCR + WebMock
* **Fixtures:** YAML/JSON responses from Tabscanner
* **Coverage:** RSpec `--format documentation --coverage`

## Security

* API key read from ENV or encrypted credentials
* No logs of sensitive data by default

## Performance

* Expected OCR response time: 2-3s
* Polling every 1s, with max timeout of 15s

## Deployment & Usage

* Gem packaged via Bundler
* Installable from local path or RubyGems (future)
* Usable via simple code snippet

```ruby
Tabscanner.configure do |c|
  c.api_key = 'abc'
  c.region = 'us'
end

token = Tabscanner.submit_receipt('receipt.jpg')
data = Tabscanner.get_result(token)
```

## Future Enhancements

* Adapter for async polling (with callbacks or Futures)
* Extend with rate limit/usage API if available
* Option to auto-store results in local DB or cloud

## Limitations

* Sync only (no async/AJAX callbacks)
* No native CLI or web front-end
* Assumes stable REST API with JSON response

