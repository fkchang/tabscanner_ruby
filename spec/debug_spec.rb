# frozen_string_literal: true

RSpec.describe 'Debug Functionality' do
  before do
    Tabscanner::Config.reset!
  end

  describe 'Configuration debug options' do
    it 'supports debug flag from environment variable' do
      ENV['TABSCANNER_DEBUG'] = 'true'
      
      config = Tabscanner::Config.instance
      expect(config.debug?).to be true
      
      ENV.delete('TABSCANNER_DEBUG')
    end

    it 'defaults debug to false when env var not set' do
      ENV.delete('TABSCANNER_DEBUG')
      
      config = Tabscanner::Config.instance
      expect(config.debug?).to be false
    end

    it 'allows setting debug via configuration block' do
      Tabscanner.configure do |config|
        config.debug = true
      end

      expect(Tabscanner.config.debug?).to be true
    end

    it 'provides default logger when none configured' do
      config = Tabscanner::Config.instance
      logger = config.logger
      
      expect(logger).to be_a(Logger)
      expect(logger.level).to eq(Logger::WARN)
    end

    it 'sets logger level to DEBUG when debug mode enabled' do
      Tabscanner.configure do |config|
        config.debug = true
      end

      logger = Tabscanner.config.logger
      expect(logger.level).to eq(Logger::DEBUG)
    end

    it 'allows custom logger configuration' do
      custom_logger = Logger.new(StringIO.new)
      
      Tabscanner.configure do |config|
        config.logger = custom_logger
      end

      expect(Tabscanner.config.logger).to eq(custom_logger)
    end
  end

  describe 'Error classes with debug info' do
    let(:sample_response) do
      {
        status: 500,
        headers: { 'Content-Type' => 'application/json' },
        body: '{"error": "Internal server error"}'
      }
    end

    it 'stores raw response data in errors' do
      error = Tabscanner::Error.new("Test error", raw_response: sample_response)
      
      expect(error.raw_response).to eq(sample_response)
    end

    it 'includes debug info in error message when debug enabled' do
      Tabscanner.configure do |config|
        config.debug = true
      end

      error = Tabscanner::Error.new("Test error", raw_response: sample_response)
      
      expect(error.message).to include("Test error")
      expect(error.message).to include("Debug Information:")
      expect(error.message).to include("Status: 500")
      expect(error.message).to include('{"error": "Internal server error"}')
    end

    it 'excludes debug info when debug disabled' do
      Tabscanner.configure do |config|
        config.debug = false
      end

      error = Tabscanner::Error.new("Test error", raw_response: sample_response)
      
      expect(error.message).to eq("Test error")
      expect(error.message).not_to include("Debug Information:")
    end

    it 'works with all error subclasses' do
      Tabscanner.configure do |config|
        config.debug = true
      end

      unauthorized_error = Tabscanner::UnauthorizedError.new("Auth failed", raw_response: sample_response)
      validation_error = Tabscanner::ValidationError.new("Validation failed", raw_response: sample_response)
      server_error = Tabscanner::ServerError.new("Server failed", raw_response: sample_response)

      expect(unauthorized_error.message).to include("Debug Information:")
      expect(validation_error.message).to include("Debug Information:")
      expect(server_error.message).to include("Debug Information:")
    end
  end

  describe 'Request class debug logging' do
    before do
      Tabscanner.configure do |config|
        config.api_key = 'test_api_key'
        config.region = 'us'
        config.debug = true
        config.logger = Logger.new(StringIO.new)
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

    it 'logs HTTP requests and responses when debug enabled' do
      logger_output = StringIO.new
      Tabscanner.config.logger = Logger.new(logger_output)

      stub_request(:post, "https://api.tabscanner.com/process")
        .to_return(
          status: 200,
          body: '{"token": "debug_token"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      result = Tabscanner::Request.submit_receipt(temp_file.path)
      
      log_content = logger_output.string
      expect(log_content).to include("HTTP Request: POST process")
      expect(log_content).to include("HTTP Response: 200")
      expect(log_content).to include("Response Body:")
      expect(result).to eq("debug_token")
    end

    it 'does not log when debug disabled' do
      Tabscanner.configure do |config|
        config.debug = false
      end

      logger_output = StringIO.new
      Tabscanner.config.logger = Logger.new(logger_output)

      stub_request(:post, "https://api.tabscanner.com/process")
        .to_return(
          status: 200,
          body: '{"token": "no_debug_token"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      result = Tabscanner::Request.submit_receipt(temp_file.path)
      
      log_content = logger_output.string
      expect(log_content).not_to include("HTTP Request")
      expect(log_content).not_to include("HTTP Response")
      expect(result).to eq("no_debug_token")
    end

    it 'includes enhanced error details with raw response' do
      Tabscanner.configure do |config|
        config.debug = true
      end

      stub_request(:post, "https://api.tabscanner.com/process")
        .to_return(
          status: 422,
          body: '{"error": "Invalid image format"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      expect {
        Tabscanner::Request.submit_receipt(temp_file.path)
      }.to raise_error(Tabscanner::ValidationError) do |error|
        expect(error.message).to include("Invalid image format")
        expect(error.message).to include("Debug Information:")
        expect(error.message).to include("Status: 422")
        expect(error.raw_response[:status]).to eq(422)
        expect(error.raw_response[:body]).to include("Invalid image format")
      end
    end
  end

  describe 'Result class debug logging' do
    before do
      Tabscanner.configure do |config|
        config.api_key = 'test_api_key'
        config.region = 'us'
        config.debug = true
        config.logger = Logger.new(StringIO.new)
      end
    end

    let(:token) { 'debug_token_123' }
    let(:api_url) { "https://api.tabscanner.com/result/#{token}" }

    it 'logs polling start and progress when debug enabled' do
      logger_output = StringIO.new
      Tabscanner.config.logger = Logger.new(logger_output)

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
            'data' => { 'merchant' => 'Debug Store' }
          }),
          headers: { 'Content-Type' => 'application/json' }
        )

      allow(Tabscanner::Result).to receive(:sleep)

      result = Tabscanner::Result.get_result(token)
      
      log_content = logger_output.string
      expect(log_content).to include("Starting result polling for token: #{token}")
      expect(log_content).to include("Result still processing for token: #{token}")
      expect(log_content).to include("Result ready for token: #{token}")
      expect(log_content).to include("HTTP Request: GET result/#{token}")
      expect(result['merchant']).to eq('Debug Store')
    end

    it 'logs failure details when processing fails' do
      logger_output = StringIO.new
      Tabscanner.config.logger = Logger.new(logger_output)

      stub_request(:get, api_url)
        .to_return(
          status: 200,
          body: JSON.dump({
            'status' => 'failed',
            'error' => 'Processing failed due to poor image quality'
          }),
          headers: { 'Content-Type' => 'application/json' }
        )

      expect {
        Tabscanner::Result.get_result(token)
      }.to raise_error(Tabscanner::Error, 'Processing failed due to poor image quality')
      
      log_content = logger_output.string
      expect(log_content).to include("Result failed for token: #{token} - Processing failed due to poor image quality")
    end

    it 'does not log when debug disabled' do
      Tabscanner.configure do |config|
        config.debug = false
      end

      logger_output = StringIO.new
      Tabscanner.config.logger = Logger.new(logger_output)

      stub_request(:get, api_url)
        .to_return(
          status: 200,
          body: JSON.dump({
            'status' => 'complete',
            'data' => { 'merchant' => 'No Debug Store' }
          }),
          headers: { 'Content-Type' => 'application/json' }
        )

      result = Tabscanner::Result.get_result(token)
      
      log_content = logger_output.string
      expect(log_content).not_to include("Starting result polling")
      expect(log_content).not_to include("HTTP Request")
      expect(result['merchant']).to eq('No Debug Store')
    end

    it 'includes enhanced error details for HTTP errors' do
      Tabscanner.configure do |config|
        config.debug = true
      end

      stub_request(:get, api_url)
        .to_return(
          status: 401,
          body: '{"error": "Token expired"}',
          headers: { 'Content-Type' => 'application/json' }
        )

      expect {
        Tabscanner::Result.get_result(token)
      }.to raise_error(Tabscanner::UnauthorizedError) do |error|
        expect(error.message).to include("Invalid API key or authentication failed")
        expect(error.message).to include("Debug Information:")
        expect(error.message).to include("Status: 401")
        expect(error.raw_response[:status]).to eq(401)
        expect(error.raw_response[:body]).to include("Token expired")
      end
    end
  end

  describe 'Integration with existing tests' do
    it 'does not break existing functionality when debug disabled' do
      Tabscanner.configure do |config|
        config.api_key = 'test_api_key'
        config.region = 'us'
        config.debug = false
      end

      # This should work exactly as before
      expect(Tabscanner.config.api_key).to eq('test_api_key')
      expect(Tabscanner.config.debug?).to be false
    end

    it 'enhances existing functionality when debug enabled' do
      Tabscanner.configure do |config|
        config.api_key = 'test_api_key'
        config.region = 'us'
        config.debug = true
      end

      # This should work with enhanced debugging
      expect(Tabscanner.config.api_key).to eq('test_api_key')
      expect(Tabscanner.config.debug?).to be true
      expect(Tabscanner.config.logger).to be_a(Logger)
      expect(Tabscanner.config.logger.level).to eq(Logger::DEBUG)
    end
  end
end