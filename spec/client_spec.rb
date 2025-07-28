# frozen_string_literal: true

RSpec.describe Tabscanner::Client do
  before do
    Tabscanner.configure do |config|
      config.api_key = 'test_api_key'
      config.region = 'us'
    end
  end

  describe '.submit_receipt' do
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

    it 'delegates to Request.submit_receipt' do
      expect(Tabscanner::Request).to receive(:submit_receipt)
        .with(temp_file.path)
        .and_return('delegated_token')

      result = described_class.submit_receipt(temp_file.path)
      expect(result).to eq('delegated_token')
    end

    it 'passes through file path arguments correctly' do
      expect(Tabscanner::Request).to receive(:submit_receipt)
        .with('/path/to/receipt.jpg')
        .and_return('path_token')

      result = described_class.submit_receipt('/path/to/receipt.jpg')
      expect(result).to eq('path_token')
    end

    it 'passes through IO stream arguments correctly' do
      File.open(temp_file.path, 'rb') do |file|
        expect(Tabscanner::Request).to receive(:submit_receipt)
          .with(file)
          .and_return('io_token')

        result = described_class.submit_receipt(file)
        expect(result).to eq('io_token')
      end
    end

    it 'passes through all errors from Request class' do
      expect(Tabscanner::Request).to receive(:submit_receipt)
        .and_raise(Tabscanner::UnauthorizedError.new('Invalid API key'))

      expect {
        described_class.submit_receipt(temp_file.path)
      }.to raise_error(Tabscanner::UnauthorizedError, 'Invalid API key')
    end
  end

  describe '.get_result' do
    let(:token) { 'test_token_123' }
    let(:sample_result) { { 'merchant' => 'Test Store', 'total' => 25.99 } }

    it 'delegates to Result.get_result with default timeout' do
      expect(Tabscanner::Result).to receive(:get_result)
        .with(token, timeout: 15)
        .and_return(sample_result)

      result = described_class.get_result(token)
      expect(result).to eq(sample_result)
    end

    it 'delegates to Result.get_result with custom timeout' do
      expect(Tabscanner::Result).to receive(:get_result)
        .with(token, timeout: 30)
        .and_return(sample_result)

      result = described_class.get_result(token, timeout: 30)
      expect(result).to eq(sample_result)
    end

    it 'passes through token argument correctly' do
      expect(Tabscanner::Result).to receive(:get_result)
        .with('another_token', timeout: 15)
        .and_return(sample_result)

      result = described_class.get_result('another_token')
      expect(result).to eq(sample_result)
    end

    it 'passes through all errors from Result class' do
      expect(Tabscanner::Result).to receive(:get_result)
        .and_raise(Tabscanner::Error.new('Timeout waiting for result'))

      expect {
        described_class.get_result(token)
      }.to raise_error(Tabscanner::Error, 'Timeout waiting for result')
    end
  end
end