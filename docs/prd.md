# Product Requirements Document (PRD): Tabscanner Ruby Gem

## Overview

This document specifies the requirements for the Tabscanner Ruby Gem, a lightweight SDK that enables Ruby developers to interact with the Tabscanner receipt OCR API.

## Problem Statement

Developers working in Ruby currently lack an official or well-supported SDK for Tabscanner. Manual HTTP request handling is error-prone, inconsistent, and discourages adoption. A gem will reduce friction, standardize usage, and improve developer productivity.

## Goals

* Provide a minimal, intuitive Ruby interface to Tabscanner's REST API
* Abstract away request details and polling mechanics
* Ensure robust error handling and clear failure modes
* Support unit testing via VCR for all HTTP interactions

## Features

### 1. Configuration

* API key and region should be configurable via ENV or initializer
* API base URL can be overridden (for staging/testing)

**Example:**

```ruby
Tabscanner.configure do |config|
  config.api_key = ENV['TABSCANNER_API_KEY']
  config.region = 'us'
end
```

### 2. Submit Receipt

* Accept a local file path or IO stream
* POST the image to the Tabscanner `process` endpoint
* Return token or error

**Method:**

```ruby
Tabscanner.submit_receipt(file_path_or_io) => 'token123'
```

### 3. Poll Result

* GET the `result` endpoint with the token
* Retry if status is "processing"
* Raise error if failure
* Return parsed receipt data as a Ruby hash

**Method:**

```ruby
Tabscanner.get_result(token, timeout: 15) => { data: {...} }
```

### 4. Error Handling

* Raise specific error classes for common API failures:

  * Unauthorized (401)
  * ValidationError (422)
  * ServerError (500+)

**Usage:**

```ruby
begin
  Tabscanner.get_result(token)
rescue Tabscanner::UnauthorizedError => e
  puts "Invalid credentials"
rescue Tabscanner::ServerError => e
  puts "Try again later"
end
```

### 5. Logging & Debugging

* Option to enable debug logging (to STDOUT or logger)
* Include raw JSON in exception messages if debug enabled

### 6. Testing

* Gem must use RSpec for tests
* Use VCR to record real HTTP interactions
* Provide fixtures for mock responses

## Non-Goals

* No CLI or web UI
* No Rails-specific code
* No async callbacks (yet)

## Success Metrics

* Gem installs via Bundler with no errors
* Full round trip from file to parsed JSON in under 10 lines
* > 90% test coverage (unit + integration)

## Dependencies

* `faraday` or `http` for HTTP client
* `json` for parsing
* `rspec`, `vcr`, `webmock` for test suite

## Risks

* Tabscanner API rate limits or outages
* Unclear versioning or change logs from Tabscanner

## Out of Scope

* Upload from remote URLs or base64
* Support for batch endpoints
* Localization/multi-language parsing

## Future Enhancements

* CLI wrapper for dev tools
* Async polling
* S3 upload wrappers
* Add support for usage tracking if Tabscanner exposes that info
