# frozen_string_literal: true

RSpec.describe Tabscanner::Credits do
  let(:api_key) { 'test-api-key-123' }
  let(:base_url) { 'https://api.tabscanner.com' }

  before do
    Tabscanner.config.api_key = api_key
    Tabscanner.config.base_url = base_url
  end

  describe '.get_credits' do
    context 'when API returns valid credit count' do
      it 'returns integer credit count for whole number' do
        stub_request(:get, "#{base_url}/api/credit")
          .with(headers: {
            'apikey' => api_key,
            'User-Agent' => "Tabscanner Ruby Gem #{Tabscanner::VERSION}",
            'Accept' => 'application/json'
          })
          .to_return(
            status: 200,
            body: '150',
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.get_credits
        expect(result).to eq(150)
        expect(result).to be_a(Integer)
      end

      it 'converts float to integer' do
        stub_request(:get, "#{base_url}/api/credit")
          .with(headers: {
            'apikey' => api_key,
            'User-Agent' => "Tabscanner Ruby Gem #{Tabscanner::VERSION}",
            'Accept' => 'application/json'
          })
          .to_return(
            status: 200,
            body: '150.5',
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.get_credits
        expect(result).to eq(150)
        expect(result).to be_a(Integer)
      end

      it 'handles zero credits' do
        stub_request(:get, "#{base_url}/api/credit")
          .with(headers: {
            'apikey' => api_key,
            'User-Agent' => "Tabscanner Ruby Gem #{Tabscanner::VERSION}",
            'Accept' => 'application/json'
          })
          .to_return(
            status: 200,
            body: '0',
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.get_credits
        expect(result).to eq(0)
      end
    end

    context 'when API returns 401 unauthorized' do
      it 'raises UnauthorizedError' do
        stub_request(:get, "#{base_url}/api/credit")
          .with(headers: {
            'apikey' => api_key,
            'User-Agent' => "Tabscanner Ruby Gem #{Tabscanner::VERSION}",
            'Accept' => 'application/json'
          })
          .to_return(
            status: 401,
            body: '{"error": "Invalid API key"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_credits
        }.to raise_error(Tabscanner::UnauthorizedError, "Invalid API key or authentication failed")
      end

      it 'includes raw response data in error' do
        stub_request(:get, "#{base_url}/api/credit")
          .to_return(status: 401, body: '{"error": "Invalid API key"}')

        begin
          described_class.get_credits
        rescue Tabscanner::UnauthorizedError => e
          expect(e.raw_response[:status]).to eq(401)
          expect(e.raw_response[:body]).to eq('{"error": "Invalid API key"}')
        end
      end
    end

    context 'when API returns server error' do
      it 'raises ServerError for 500 status' do
        stub_request(:get, "#{base_url}/api/credit")
          .to_return(
            status: 500,
            body: '{"error": "Internal server error"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_credits
        }.to raise_error(Tabscanner::ServerError, "Internal server error")
      end

      it 'raises ServerError for 503 status' do
        stub_request(:get, "#{base_url}/api/credit")
          .to_return(
            status: 503,
            body: '{"message": "Service unavailable"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_credits
        }.to raise_error(Tabscanner::ServerError, "Service unavailable")
      end

      it 'uses default error message when none provided' do
        stub_request(:get, "#{base_url}/api/credit")
          .to_return(status: 500, body: '')

        expect {
          described_class.get_credits
        }.to raise_error(Tabscanner::ServerError, "Server error occurred")
      end
    end

    context 'when API returns invalid JSON' do
      it 'raises Error for malformed JSON' do
        stub_request(:get, "#{base_url}/api/credit")
          .to_return(
            status: 200,
            body: 'invalid json',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_credits
        }.to raise_error(Tabscanner::Error, "Invalid JSON response from API")
      end

      it 'raises Error for non-numeric response' do
        stub_request(:get, "#{base_url}/api/credit")
          .to_return(
            status: 200,
            body: '"not a number"',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_credits
        }.to raise_error(Tabscanner::Error, "Invalid credit response format: expected number, got String")
      end

      it 'raises Error for object response' do
        stub_request(:get, "#{base_url}/api/credit")
          .to_return(
            status: 200,
            body: '{"credits": 150}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_credits
        }.to raise_error(Tabscanner::Error, "Invalid credit response format: expected number, got Hash")
      end
    end

    context 'when API returns other error status' do
      it 'raises Error for unexpected status codes' do
        stub_request(:get, "#{base_url}/api/credit")
          .to_return(
            status: 429,
            body: '{"error": "Rate limit exceeded"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_credits
        }.to raise_error(Tabscanner::Error, "Rate limit exceeded")
      end

      it 'uses default error message for unknown status' do
        stub_request(:get, "#{base_url}/api/credit")
          .to_return(status: 418, body: '')

        expect {
          described_class.get_credits
        }.to raise_error(Tabscanner::Error, "Request failed with status 418")
      end
    end

    context 'with configuration validation' do
      it 'validates configuration before making request' do
        Tabscanner.config.api_key = nil

        expect {
          described_class.get_credits
        }.to raise_error(Tabscanner::ConfigurationError)
      end
    end

    context 'with custom base URL' do
      it 'uses custom base URL when configured' do
        custom_url = 'https://custom.api.example.com'
        Tabscanner.config.base_url = custom_url

        stub_request(:get, "#{custom_url}/api/credit")
          .to_return(status: 200, body: '100')

        result = described_class.get_credits
        expect(result).to eq(100)
      end

      it 'falls back to default URL when not configured' do
        Tabscanner.config.base_url = nil

        stub_request(:get, "https://api.tabscanner.com/api/credit")
          .to_return(status: 200, body: '100')

        result = described_class.get_credits
        expect(result).to eq(100)
      end
    end
  end

  describe 'HTTP request configuration' do
    it 'sends correct headers' do
      request_stub = stub_request(:get, "#{base_url}/api/credit")
        .with(headers: {
          'apikey' => api_key,
          'User-Agent' => "Tabscanner Ruby Gem #{Tabscanner::VERSION}",
          'Accept' => 'application/json'
        })
        .to_return(status: 200, body: '150')

      described_class.get_credits

      expect(request_stub).to have_been_requested
    end

    it 'makes GET request to correct endpoint' do
      request_stub = stub_request(:get, "#{base_url}/api/credit")
        .to_return(status: 200, body: '150')

      described_class.get_credits

      expect(request_stub).to have_been_requested
    end
  end

  describe 'debug logging' do
    let(:logger) { double('logger') }

    before do
      Tabscanner.config.debug = true
      Tabscanner.config.logger = logger
    end

    it 'logs request and response when debug enabled' do
      stub_request(:get, "#{base_url}/api/credit")
        .to_return(status: 200, body: '150')

      expect(logger).to receive(:debug).with("HTTP Request: GET /api/credit")
      expect(logger).to receive(:debug).with(/Request Headers: apikey=\[REDACTED\]/)
      expect(logger).to receive(:debug).with("HTTP Response: 200")
      expect(logger).to receive(:debug).with(/Response Headers:/)
      expect(logger).to receive(:debug).with("Response Body: 150")

      described_class.get_credits
    end

    it 'does not log when debug disabled' do
      Tabscanner.config.debug = false

      stub_request(:get, "#{base_url}/api/credit")
        .to_return(status: 200, body: '150')

      expect(logger).not_to receive(:debug)

      described_class.get_credits
    end

    it 'truncates long response bodies in logs' do
      long_body = 'x' * 600
      stub_request(:get, "#{base_url}/api/credit")
        .to_return(status: 200, body: long_body)

      expect(logger).to receive(:debug).with("HTTP Request: GET /api/credit")
      expect(logger).to receive(:debug).with(/Request Headers: apikey=\[REDACTED\]/)
      expect(logger).to receive(:debug).with("HTTP Response: 200")
      expect(logger).to receive(:debug).with(/Response Headers:/)
      expect(logger).to receive(:debug).with(/Response Body: #{'x' * 500}.*\.\.\. \(truncated\)/)

      expect {
        described_class.get_credits
      }.to raise_error(Tabscanner::Error) # This will fail JSON parsing, but we're testing logging
    end
  end
end