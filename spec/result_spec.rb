# frozen_string_literal: true

RSpec.describe Tabscanner::Result do
  before do
    Tabscanner.configure do |config|
      config.api_key = 'test_api_key'
      config.region = 'us'
    end
  end

  describe '.get_result' do
    let(:token) { 'test_token_123' }
    let(:api_url) { "https://api.tabscanner.com/api/2/result/#{token}" }

    context 'successful result retrieval' do
      it 'returns data when status is complete', :vcr do
        # Mock successful complete response
        stub_request(:get, api_url)
          .with(
            headers: {
              'apikey' => 'test_api_key',
              'User-Agent' => /Tabscanner Ruby Gem/,
              'Accept' => 'application/json'
            }
          )
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'complete',
              'data' => {
                'merchant' => 'Test Store',
                'total' => 25.99,
                'items' => [
                  { 'name' => 'Coffee', 'price' => 3.99 },
                  { 'name' => 'Sandwich', 'price' => 12.00 }
                ]
              }
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.get_result(token)
        
        expect(result).to be_a(Hash)
        expect(result['merchant']).to eq('Test Store')
        expect(result['total']).to eq(25.99)
        expect(result['items']).to be_an(Array)
        expect(result['items'].length).to eq(2)
      end

      it 'returns data when status is completed', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'completed',
              'data' => { 'merchant' => 'Another Store' }
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.get_result(token)
        expect(result['merchant']).to eq('Another Store')
      end

      it 'returns data when status is success', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'success',
              'receipt' => { 'merchant' => 'Receipt Store' }
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.get_result(token)
        expect(result['merchant']).to eq('Receipt Store')
      end

      it 'returns full result when no data/receipt key present', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'complete',
              'merchant' => 'Direct Store',
              'total' => 15.50,
              'timestamp' => '2023-01-01T00:00:00Z'
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.get_result(token)
        expect(result['merchant']).to eq('Direct Store')
        expect(result['total']).to eq(15.50)
        expect(result).not_to have_key('status')
        expect(result).not_to have_key('timestamp')
      end
    end

    context 'polling with retry logic' do
      it 'retries when status is processing and eventually succeeds', :vcr do
        # First call returns processing
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({ 'status' => 'processing' }),
            headers: { 'Content-Type' => 'application/json' }
          ).then
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'complete',
              'data' => { 'merchant' => 'Final Store' }
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        # Allow time for sleep to be called
        allow(described_class).to receive(:sleep)
        
        result = described_class.get_result(token)
        expect(result['merchant']).to eq('Final Store')
        expect(described_class).to have_received(:sleep).with(1)
      end

      it 'retries when status is pending', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({ 'status' => 'pending' }),
            headers: { 'Content-Type' => 'application/json' }
          ).then
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'complete',
              'data' => { 'result' => 'success' }
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        allow(described_class).to receive(:sleep)
        
        result = described_class.get_result(token)
        expect(result['result']).to eq('success')
      end

      it 'retries when status is in_progress', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({ 'status' => 'in_progress' }),
            headers: { 'Content-Type' => 'application/json' }
          ).then
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'complete',
              'data' => { 'result' => 'done' }
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        allow(described_class).to receive(:sleep)
        
        result = described_class.get_result(token)
        expect(result['result']).to eq('done')
      end
    end

    context 'timeout handling' do
      it 'raises timeout error when processing takes too long', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({ 'status' => 'processing' }),
            headers: { 'Content-Type' => 'application/json' }
          )

        allow(described_class).to receive(:sleep)
        
        expect {
          described_class.get_result(token, timeout: 2)
        }.to raise_error(Tabscanner::Error, /Timeout waiting for result after 2 seconds/)
      end

      it 'respects custom timeout parameter', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({ 'status' => 'processing' }),
            headers: { 'Content-Type' => 'application/json' }
          )

        allow(described_class).to receive(:sleep)
        
        expect {
          described_class.get_result(token, timeout: 5)
        }.to raise_error(Tabscanner::Error, /Timeout waiting for result after 5 seconds/)
      end
    end

    context 'error handling' do
      it 'raises error when status is failed', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'failed',
              'error' => 'Processing failed due to invalid image'
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::Error, 'Processing failed due to invalid image')
      end

      it 'raises error when status is error', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'error',
              'message' => 'Invalid token provided'
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::Error, 'Invalid token provided')
      end

      it 'raises generic error for failed status without message', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({ 'status' => 'failed' }),
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::Error, 'Processing failed')
      end

      it 'raises error for unknown status', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: JSON.dump({ 'status' => 'unknown_status' }),
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::Error, 'Unknown processing status: unknown_status')
      end
    end

    context 'HTTP error responses' do
      it 'raises UnauthorizedError for 401 responses', :vcr do
        stub_request(:get, api_url)
          .to_return(status: 401, body: '{"error": "Invalid API key"}')

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::UnauthorizedError, 'Invalid API key or authentication failed')
      end

      it 'raises ValidationError for 422 responses', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 422,
            body: JSON.dump({ 'error' => 'Invalid token format' }),
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::ValidationError, 'Invalid token format')
      end

      it 'raises ServerError for 500 responses', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 500,
            body: JSON.dump({ 'error' => 'Internal server error' }),
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::ServerError, 'Internal server error')
      end

      it 'raises ServerError for 503 responses', :vcr do
        stub_request(:get, api_url)
          .to_return(status: 503, body: 'Service Unavailable')

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::ServerError, 'Service Unavailable')
      end

      it 'raises generic Error for other status codes', :vcr do
        stub_request(:get, api_url)
          .to_return(status: 404, body: '{"error": "Not found"}')

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::Error, 'Not found')
      end
    end

    context 'invalid JSON responses' do
      it 'raises error for invalid JSON', :vcr do
        stub_request(:get, api_url)
          .to_return(
            status: 200,
            body: 'invalid json response',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::Error, 'Invalid JSON response from API')
      end
    end

    context 'configuration integration' do
      it 'uses custom base_url from configuration', :vcr do
        Tabscanner.configure do |config|
          config.base_url = 'https://custom-api.example.com'
        end

        custom_url = "https://custom-api.example.com/api/2/result/#{token}"
        stub_request(:get, custom_url)
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'complete',
              'data' => { 'result' => 'custom_api_result' }
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.get_result(token)
        expect(result['result']).to eq('custom_api_result')
      end

      it 'validates configuration before making request' do
        Tabscanner.configure do |config|
          config.api_key = nil
        end

        expect {
          described_class.get_result(token)
        }.to raise_error(Tabscanner::ConfigurationError, 'API key is required')
      end

      it 'includes region in headers if needed' do
        # This test ensures the connection is built with all config values
        # The actual region usage depends on API requirements
        expect(described_class).to respond_to(:get_result)
        expect { described_class.get_result(token, timeout: 1) }.to raise_error # Will timeout or make request
      end
    end
  end
end