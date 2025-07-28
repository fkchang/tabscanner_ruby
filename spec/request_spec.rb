# frozen_string_literal: true

RSpec.describe Tabscanner::Request do
  before do
    Tabscanner.configure do |config|
      config.api_key = 'test_api_key'
      config.region = 'us'
    end
  end

  describe '.submit_receipt' do
    let(:image_content) { "fake_image_data" }
    let(:temp_file) { Tempfile.new(['test_receipt', '.jpg']) }

    before do
      temp_file.write(image_content)
      temp_file.rewind
    end

    after do
      temp_file.close
      temp_file.unlink
    end

    context 'with file path input' do
      it 'successfully submits receipt and returns token', :vcr do
        # Mock successful response
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .with(
            headers: {
              'apikey' => 'test_api_key',
              'User-Agent' => /Tabscanner Ruby Gem/
            }
          )
          .to_return(
            status: 200,
            body: '{"token": "abc123def456"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.submit_receipt(temp_file.path)
        expect(result).to eq('abc123def456')
      end

      it 'raises error for non-existent file' do
        expect {
          described_class.submit_receipt('/non/existent/file.jpg')
        }.to raise_error(Tabscanner::Error, /File not found/)
      end
    end

    context 'with IO stream input' do
      it 'successfully submits receipt and returns token' do
        # Mock successful response
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: '{"token": "stream123token"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        File.open(temp_file.path, 'rb') do |file|
          result = described_class.submit_receipt(file)
          expect(result).to eq('stream123token')
        end
      end

      it 'handles StringIO input' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: '{"token": "stringio456"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        string_io = StringIO.new(image_content)
        result = described_class.submit_receipt(string_io)
        expect(result).to eq('stringio456')
      end
    end

    context 'response token extraction' do
      it 'extracts token from response body' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: '{"token": "extracted_token"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.submit_receipt(temp_file.path)
        expect(result).to eq('extracted_token')
      end

      it 'extracts id field as token when token field missing' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 201,
            body: '{"id": "id_as_token"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.submit_receipt(temp_file.path)
        expect(result).to eq('id_as_token')
      end

      it 'extracts request_id field as token when others missing' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: '{"request_id": "request_token"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.submit_receipt(temp_file.path)
        expect(result).to eq('request_token')
      end

      it 'raises error when no token found in response' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: '{"status": "success"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::Error, /No token found in response/)
      end

      it 'raises error for invalid JSON response' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: 'invalid json{',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::Error, /Invalid JSON response/)
      end
    end

    context 'error handling' do
      it 'raises UnauthorizedError for 401 status' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 401,
            body: '{"error": "Invalid API key"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::UnauthorizedError, /Invalid API key/)
      end

      it 'raises ValidationError for 422 status' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 422,
            body: '{"error": "Invalid image format"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::ValidationError, /Invalid image format/)
      end

      it 'raises ServerError for 500 status' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 500,
            body: '{"error": "Internal server error"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::ServerError, /Internal server error/)
      end

      it 'raises ServerError for 503 status' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 503,
            body: '{"error": "Service unavailable"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::ServerError, /Service unavailable/)
      end

      it 'raises generic Error for other status codes' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 429,
            body: '{"error": "Rate limit exceeded"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect {
          described_class.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::Error, /Rate limit exceeded/)
      end

      it 'provides default error messages when body parsing fails' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(status: 422, body: 'invalid json')

        expect {
          described_class.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::ValidationError, /invalid json/)
      end

      it 'uses raw body as error message for short responses' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(status: 500, body: 'Server overloaded')

        expect {
          described_class.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::ServerError, /Server overloaded/)
      end
    end

    context 'configuration integration' do
      it 'uses custom base_url when configured' do
        Tabscanner.configure do |config|
          config.base_url = 'https://staging.tabscanner.com'
        end

        stub_request(:post, "https://staging.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: '{"token": "staging_token"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        result = described_class.submit_receipt(temp_file.path)
        expect(result).to eq('staging_token')
      end

      it 'validates configuration before making request' do
        Tabscanner.configure do |config|
          config.api_key = nil
        end

        expect {
          described_class.submit_receipt(temp_file.path)
        }.to raise_error(Tabscanner::ConfigurationError, /API key is required/)
      end

      it 'includes User-Agent header with gem version' do
        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .with(
            headers: {
              'User-Agent' => "Tabscanner Ruby Gem #{Tabscanner::VERSION}"
            }
          )
          .to_return(
            status: 200,
            body: '{"token": "version_test"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        described_class.submit_receipt(temp_file.path)
      end
    end

    context 'multipart form handling' do
      it 'sets correct MIME type for JPEG files' do
        jpeg_file = Tempfile.new(['test', '.jpg'])
        jpeg_file.write(image_content)
        jpeg_file.rewind

        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: '{"token": "mime_test"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        described_class.submit_receipt(jpeg_file.path)

        jpeg_file.close
        jpeg_file.unlink
      end

      it 'sets correct MIME type for PNG files' do
        png_file = Tempfile.new(['test', '.png'])
        png_file.write(image_content)
        png_file.rewind

        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: '{"token": "png_test"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        described_class.submit_receipt(png_file.path)

        png_file.close
        png_file.unlink
      end

      it 'defaults to image/jpeg for unknown file types' do
        unknown_file = Tempfile.new(['test', '.xyz'])
        unknown_file.write(image_content)
        unknown_file.rewind

        stub_request(:post, "https://api.tabscanner.com/api/2/process")
          .to_return(
            status: 200,
            body: '{"token": "unknown_test"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        described_class.submit_receipt(unknown_file.path)

        unknown_file.close
        unknown_file.unlink
      end
    end
  end
end