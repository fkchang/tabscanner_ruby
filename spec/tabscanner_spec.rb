# frozen_string_literal: true

RSpec.describe Tabscanner do
  it "has a version number" do
    expect(Tabscanner::VERSION).not_to be nil
  end

  it "provides configuration functionality" do
    expect(Tabscanner).to respond_to(:configure)
    expect(Tabscanner).to respond_to(:config)
  end

  describe '.submit_receipt' do
    before do
      Tabscanner.configure do |config|
        config.api_key = 'test_api_key'
        config.region = 'us'
      end
    end

    let(:temp_file) { Tempfile.new(['test_receipt', '.jpg']) }
    let(:image_content) { "fake_image_data" }

    before do
      temp_file.write(image_content)
      temp_file.rewind
    end

    after do
      temp_file.close
      temp_file.unlink
    end

    it 'delegates to Client.submit_receipt' do
      expect(Tabscanner::Client).to receive(:submit_receipt)
        .with(temp_file.path)
        .and_return('main_module_token')

      result = Tabscanner.submit_receipt(temp_file.path)
      expect(result).to eq('main_module_token')
    end

    it 'provides the expected public API signature' do
      # Mock the full chain to avoid actual HTTP calls
      allow(Tabscanner::Request).to receive(:submit_receipt)
        .and_return('integration_token')

      result = Tabscanner.submit_receipt(temp_file.path)
      expect(result).to eq('integration_token')
    end

    context 'integration test with mocked HTTP' do
      it 'successfully processes a receipt from file path to token' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .with(
            headers: {
              'apikey' => 'test_api_key',
              'User-Agent' => /Tabscanner Ruby Gem/
            }
          )
          .to_return(
            status: 200,
            body: '{"token": "integration_test_token"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        result = Tabscanner.submit_receipt(temp_file.path)
        expect(result).to eq('integration_test_token')
      end

      it 'successfully processes a receipt from IO stream to token' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: '{"token": "io_integration_token"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        File.open(temp_file.path, 'rb') do |file|
          result = Tabscanner.submit_receipt(file)
          expect(result).to eq('io_integration_token')
        end
      end
    end
  end

  describe '.get_result' do
    before do
      Tabscanner.configure do |config|
        config.api_key = 'test_api_key'
        config.region = 'us'
      end
    end

    let(:token) { 'test_token_123' }
    let(:sample_result) { { 'merchant' => 'Test Store', 'total' => 25.99 } }

    it 'delegates to Client.get_result' do
      expect(Tabscanner::Client).to receive(:get_result)
        .with(token, timeout: 15)
        .and_return(sample_result)

      result = Tabscanner.get_result(token)
      expect(result).to eq(sample_result)
    end

    it 'delegates to Client.get_result with custom timeout' do
      expect(Tabscanner::Client).to receive(:get_result)
        .with(token, timeout: 30)
        .and_return(sample_result)

      result = Tabscanner.get_result(token, timeout: 30)
      expect(result).to eq(sample_result)
    end

    it 'provides the expected public API signature' do
      # Mock the full chain to avoid actual HTTP calls
      allow(Tabscanner::Result).to receive(:get_result)
        .and_return(sample_result)

      result = Tabscanner.get_result(token)
      expect(result).to eq(sample_result)
    end

    context 'integration test with mocked HTTP' do
      it 'successfully polls for and retrieves result data' do
        stub_request(:get, "https://api.tabscanner.com/api/2/result/#{token}")
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
                'merchant' => 'Integration Store',
                'total' => 42.75,
                'items' => [
                  { 'name' => 'Item 1', 'price' => 20.00 },
                  { 'name' => 'Item 2', 'price' => 22.75 }
                ]
              }
            }),
            headers: { 'Content-Type' => 'application/json' }
          )

        result = Tabscanner.get_result(token)
        expect(result).to be_a(Hash)
        expect(result['merchant']).to eq('Integration Store')
        expect(result['total']).to eq(42.75)
        expect(result['items']).to be_an(Array)
        expect(result['items'].length).to eq(2)
      end
    end
  end

  describe 'full integration workflow' do
    before do
      Tabscanner.configure do |config|
        config.api_key = 'test_api_key'
        config.region = 'us'
      end
    end

    let(:temp_file) { Tempfile.new(['test_receipt', '.jpg']) }
    let(:image_content) { "fake_image_data" }
    let(:test_token) { 'workflow_token_123' }

    before do
      temp_file.write(image_content)
      temp_file.rewind
    end

    after do
      temp_file.close
      temp_file.unlink
    end

    it 'completes full workflow from file to parsed data' do
      # Mock submit receipt
      stub_request(:post, "https://api.tabscanner.com/api/2/process")
        .to_return(
          status: 200,
          body: JSON.dump({ 'token' => test_token }),
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock get result
      stub_request(:get, "https://api.tabscanner.com/api/2/result/#{test_token}")
        .to_return(
          status: 200,
          body: JSON.dump({
            'status' => 'complete',
            'data' => {
              'merchant' => 'Full Workflow Store',
              'total' => 99.99,
              'date' => '2023-01-01',
              'items' => [
                { 'name' => 'Coffee', 'price' => 4.99 },
                { 'name' => 'Muffin', 'price' => 3.50 },
                { 'name' => 'Lunch', 'price' => 91.50 }
              ]
            }
          }),
          headers: { 'Content-Type' => 'application/json' }
        )

      # Execute full workflow
      token = Tabscanner.submit_receipt(temp_file.path)
      expect(token).to eq(test_token)

      result = Tabscanner.get_result(token)
      expect(result).to be_a(Hash)
      expect(result['merchant']).to eq('Full Workflow Store')
      expect(result['total']).to eq(99.99)
      expect(result['date']).to eq('2023-01-01')
      expect(result['items'].length).to eq(3)
    end
  end
end
