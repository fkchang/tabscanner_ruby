# frozen_string_literal: true

RSpec.describe 'Integration Tests' do
  before do
    Tabscanner.configure do |config|
      config.api_key = 'test_integration_key'
      config.region = 'us'
      config.debug = false
    end
  end

  describe 'Full Workflow Integration' do
    let(:temp_file) { Tempfile.new(['integration_receipt', '.jpg']) }
    let(:image_content) { "integration_test_image_data" }
    let(:test_token) { 'integration_token_12345' }

    before do
      temp_file.write(image_content)
      temp_file.rewind
    end

    after do
      temp_file.close
      temp_file.unlink
    end

    it 'completes full workflow: submit → poll → result', :vcr do
      # Step 1: Submit receipt
      stub_request(:post, "https://api.tabscanner.com/process")
        .with(
          headers: {
            'Authorization' => 'Bearer test_integration_key',
            'User-Agent' => /Tabscanner Ruby Gem/
          }
        )
        .to_return(
          status: 200,
          body: JSON.dump({ 'token' => test_token }),
          headers: { 'Content-Type' => 'application/json' }
        )

      token = Tabscanner.submit_receipt(temp_file.path)
      expect(token).to eq(test_token)

      # Step 2: Poll for results (with processing → complete flow)
      stub_request(:get, "https://api.tabscanner.com/result/#{test_token}")
        .to_return(
          status: 200,
          body: JSON.dump({ 'status' => 'processing' }),
          headers: { 'Content-Type' => 'application/json' }
        ).then
        .to_return(
          status: 200,
          body: JSON.dump({
            'status' => 'complete',
            'data' => {
              'merchant' => 'Integration Test Store',
              'total' => 123.45,
              'date' => '2025-07-28',
              'items' => [
                { 'name' => 'Test Item 1', 'price' => 50.00 },
                { 'name' => 'Test Item 2', 'price' => 73.45 }
              ],
              'currency' => 'USD'
            }
          }),
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock sleep to speed up test
      allow(Tabscanner::Result).to receive(:sleep)

      result = Tabscanner.get_result(token, timeout: 30)

      # Step 3: Verify result structure
      expect(result).to be_a(Hash)
      expect(result['merchant']).to eq('Integration Test Store')
      expect(result['total']).to eq(123.45)
      expect(result['date']).to eq('2025-07-28')
      expect(result['items']).to be_an(Array)
      expect(result['items'].length).to eq(2)
      expect(result['currency']).to eq('USD')

      # Verify individual items
      expect(result['items'][0]['name']).to eq('Test Item 1')
      expect(result['items'][0]['price']).to eq(50.00)
      expect(result['items'][1]['name']).to eq('Test Item 2')
      expect(result['items'][1]['price']).to eq(73.45)
    end

    it 'handles complete workflow with IO stream input', :vcr do
      # Mock submit with IO
      stub_request(:post, "https://api.tabscanner.com/process")
        .to_return(
          status: 200,
          body: JSON.dump({ 'token' => 'io_stream_token' }),
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock result polling
      stub_request(:get, "https://api.tabscanner.com/result/io_stream_token")
        .to_return(
          status: 200,
          body: JSON.dump({
            'status' => 'complete',
            'data' => { 'merchant' => 'IO Stream Store', 'total' => 99.99 }
          }),
          headers: { 'Content-Type' => 'application/json' }
        )

      File.open(temp_file.path, 'rb') do |file|
        token = Tabscanner.submit_receipt(file)
        result = Tabscanner.get_result(token)
        
        expect(token).to eq('io_stream_token')
        expect(result['merchant']).to eq('IO Stream Store')
        expect(result['total']).to eq(99.99)
      end
    end

    it 'handles workflow with multiple polling cycles', :vcr do
      # Mock submit
      stub_request(:post, "https://api.tabscanner.com/process")
        .to_return(
          status: 200,
          body: JSON.dump({ 'token' => 'multi_poll_token' }),
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock multiple polling attempts: processing → processing → complete
      stub_request(:get, "https://api.tabscanner.com/result/multi_poll_token")
        .to_return(
          status: 200,
          body: JSON.dump({ 'status' => 'processing' }),
          headers: { 'Content-Type' => 'application/json' }
        ).then
        .to_return(
          status: 200,
          body: JSON.dump({ 'status' => 'processing' }),
          headers: { 'Content-Type' => 'application/json' }
        ).then
        .to_return(
          status: 200,
          body: JSON.dump({
            'status' => 'complete',
            'data' => { 'merchant' => 'Multi Poll Store', 'total' => 77.77 }
          }),
          headers: { 'Content-Type' => 'application/json' }
        )

      allow(Tabscanner::Result).to receive(:sleep)

      token = Tabscanner.submit_receipt(temp_file.path)
      result = Tabscanner.get_result(token)
      
      expect(result['merchant']).to eq('Multi Poll Store')
      expect(result['total']).to eq(77.77)
      expect(Tabscanner::Result).to have_received(:sleep).twice
    end
  end

  describe 'Error Scenario Integration' do
    let(:temp_file) { Tempfile.new(['error_receipt', '.jpg']) }

    before do
      temp_file.write("error_test_data")
      temp_file.rewind
    end

    after do
      temp_file.close
      temp_file.unlink
    end

    it 'handles authentication errors in submit workflow', :vcr do
      stub_request(:post, "https://api.tabscanner.com/process")
        .to_return(
          status: 401,
          body: JSON.dump({ 'error' => 'Invalid API key' }),
          headers: { 'Content-Type' => 'application/json' }
        )

      expect {
        Tabscanner.submit_receipt(temp_file.path)
      }.to raise_error(Tabscanner::UnauthorizedError, 'Invalid API key or authentication failed')
    end

    it 'handles validation errors in submit workflow', :vcr do
      stub_request(:post, "https://api.tabscanner.com/process")
        .to_return(
          status: 422,
          body: JSON.dump({ 'error' => 'Invalid image format' }),
          headers: { 'Content-Type' => 'application/json' }
        )

      expect {
        Tabscanner.submit_receipt(temp_file.path)
      }.to raise_error(Tabscanner::ValidationError, 'Invalid image format')
    end

    it 'handles server errors in submit workflow', :vcr do
      stub_request(:post, "https://api.tabscanner.com/process")
        .to_return(
          status: 500,
          body: JSON.dump({ 'error' => 'Internal server error' }),
          headers: { 'Content-Type' => 'application/json' }
        )

      expect {
        Tabscanner.submit_receipt(temp_file.path)
      }.to raise_error(Tabscanner::ServerError, 'Internal server error')
    end

    it 'handles processing failures in result workflow', :vcr do
      stub_request(:get, "https://api.tabscanner.com/result/failed_token")
        .to_return(
          status: 200,
          body: JSON.dump({
            'status' => 'failed',
            'error' => 'Unable to process image - poor quality'
          }),
          headers: { 'Content-Type' => 'application/json' }
        )

      expect {
        Tabscanner.get_result('failed_token')
      }.to raise_error(Tabscanner::Error, 'Unable to process image - poor quality')
    end

    it 'handles timeout scenarios', :vcr do
      stub_request(:get, "https://api.tabscanner.com/result/timeout_token")
        .to_return(
          status: 200,
          body: JSON.dump({ 'status' => 'processing' }),
          headers: { 'Content-Type' => 'application/json' }
        )

      allow(Tabscanner::Result).to receive(:sleep)

      expect {
        Tabscanner.get_result('timeout_token', timeout: 2)
      }.to raise_error(Tabscanner::Error, /Timeout waiting for result after 2 seconds/)
    end
  end

  describe 'Configuration Integration' do
    it 'works with custom base URL configuration', :vcr do
      Tabscanner.configure do |config|
        config.api_key = 'custom_url_key'
        config.base_url = 'https://custom.tabscanner.example.com'
      end

      temp_file = Tempfile.new(['custom_receipt', '.jpg'])
      temp_file.write("custom_test_data")
      temp_file.rewind

      begin
        stub_request(:post, "https://custom.tabscanner.example.com/process")
          .to_return(
            status: 200,
            body: JSON.dump({ 'token' => 'custom_token' }),
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, "https://custom.tabscanner.example.com/result/custom_token")
          .to_return(
            status: 200,
            body: JSON.dump({
              'status' => 'complete',
              'data' => { 'merchant' => 'Custom URL Store', 'total' => 88.88 }
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        token = Tabscanner.submit_receipt(temp_file.path)
        result = Tabscanner.get_result(token)

        expect(token).to eq('custom_token')
        expect(result['merchant']).to eq('Custom URL Store')
        expect(result['total']).to eq(88.88)
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    it 'validates configuration before making requests', :vcr do
      Tabscanner.configure do |config|
        config.api_key = nil  # Invalid configuration
      end

      temp_file = Tempfile.new(['invalid_config', '.jpg'])
      temp_file.write("test_data")
      temp_file.rewind

      begin
        expect {
          Tabscanner.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::ConfigurationError, 'API key is required')
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
  end

  describe 'Debug Mode Integration' do
    it 'provides enhanced error details in debug mode', :vcr do
      Tabscanner.configure do |config|
        config.api_key = 'debug_test_key'
        config.debug = true
      end

      temp_file = Tempfile.new(['debug_receipt', '.jpg'])
      temp_file.write("debug_test_data")
      temp_file.rewind

      begin
        stub_request(:post, "https://api.tabscanner.com/process")
          .to_return(
            status: 422,
            body: JSON.dump({ 'error' => 'Debug mode validation error' }),
            headers: { 
              'Content-Type' => 'application/json',
              'X-Request-ID' => 'debug-12345'
            }
          )

        expect {
          Tabscanner.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::ValidationError) do |error|
          expect(error.message).to include('Debug mode validation error')
          expect(error.message).to include('Debug Information:')
          expect(error.message).to include('Status: 422')
          expect(error.raw_response).to be_a(Hash)
          expect(error.raw_response[:status]).to eq(422)
          expect(error.raw_response[:body]).to include('Debug mode validation error')
        end
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
  end
end