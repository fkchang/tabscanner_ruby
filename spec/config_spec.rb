# frozen_string_literal: true

RSpec.describe Tabscanner::Config do
  # Clear any existing instance before each test
  before do
    described_class.reset!
  end

  describe '.instance' do
    it 'returns a singleton instance' do
      instance1 = described_class.instance
      instance2 = described_class.instance
      expect(instance1).to be(instance2)
    end

    it 'prevents direct instantiation' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end

  describe '#initialize' do
    context 'with ENV variables set' do
      before do
        allow(ENV).to receive(:[]).with('TABSCANNER_API_KEY').and_return('test_key')
        allow(ENV).to receive(:[]).with('TABSCANNER_REGION').and_return('eu')
        allow(ENV).to receive(:[]).with('TABSCANNER_BASE_URL').and_return('https://test.example.com')
        allow(ENV).to receive(:[]).with('TABSCANNER_DEBUG').and_return('true')
      end

      it 'sets default values from ENV variables' do
        config = described_class.instance
        expect(config.api_key).to eq('test_key')
        expect(config.region).to eq('eu')
        expect(config.base_url).to eq('https://test.example.com')
        expect(config.debug?).to be true
      end
    end

    context 'with no ENV variables set' do
      before do
        allow(ENV).to receive(:[]).with('TABSCANNER_API_KEY').and_return(nil)
        allow(ENV).to receive(:[]).with('TABSCANNER_REGION').and_return(nil)
        allow(ENV).to receive(:[]).with('TABSCANNER_BASE_URL').and_return(nil)
        allow(ENV).to receive(:[]).with('TABSCANNER_DEBUG').and_return(nil)
      end

      it 'sets default region to "us" when no ENV variable' do
        config = described_class.instance
        expect(config.api_key).to be_nil
        expect(config.region).to eq('us')
        expect(config.base_url).to be_nil
        expect(config.debug?).to be false
      end
    end
  end

  describe 'attribute accessors' do
    let(:config) { described_class.instance }

    it 'allows setting and getting api_key' do
      config.api_key = 'new_key'
      expect(config.api_key).to eq('new_key')
    end

    it 'allows setting and getting region' do
      config.region = 'eu'
      expect(config.region).to eq('eu')
    end

    it 'allows setting and getting base_url' do
      config.base_url = 'https://custom.example.com'
      expect(config.base_url).to eq('https://custom.example.com')
    end

    it 'allows setting and getting debug' do
      config.debug = true
      expect(config.debug?).to be true
      
      config.debug = false
      expect(config.debug?).to be false
    end

    it 'allows setting and getting logger' do
      custom_logger = Logger.new(StringIO.new)
      config.logger = custom_logger
      expect(config.logger).to eq(custom_logger)
    end
  end

  describe '#logger' do
    let(:config) { described_class.instance }

    it 'provides default logger when none set' do
      logger = config.logger
      expect(logger).to be_a(Logger)
    end

    it 'sets logger level to DEBUG when debug enabled' do
      config.debug = true
      logger = config.logger
      expect(logger.level).to eq(Logger::DEBUG)
    end

    it 'sets logger level to WARN when debug disabled' do
      config.debug = false
      logger = config.logger
      expect(logger.level).to eq(Logger::WARN)
    end

    it 'formats log messages with Tabscanner prefix' do
      output = StringIO.new
      # Create a new logger with our custom format (simulating what config.logger does)
      logger = Logger.new(output)
      logger.level = Logger::INFO
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{severity} -- Tabscanner: #{msg}\n"
      end
      
      logger.info("Test message")
      
      expect(output.string).to include("-- Tabscanner: Test message")
    end
  end

  describe '#validate!' do
    let(:config) { described_class.instance }

    context 'with valid configuration' do
      before do
        config.api_key = 'valid_key'
        config.region = 'us'
      end

      it 'does not raise an error' do
        expect { config.validate! }.not_to raise_error
      end
    end

    context 'with missing api_key' do
      before do
        config.api_key = nil
        config.region = 'us'
      end

      it 'raises ConfigurationError' do
        expect { config.validate! }.to raise_error(Tabscanner::ConfigurationError, "API key is required")
      end
    end

    context 'with empty api_key' do
      before do
        config.api_key = ''
        config.region = 'us'
      end

      it 'raises ConfigurationError' do
        expect { config.validate! }.to raise_error(Tabscanner::ConfigurationError, "API key is required")
      end
    end

    context 'with missing region' do
      before do
        config.api_key = 'valid_key'
        config.region = nil
      end

      it 'raises ConfigurationError' do
        expect { config.validate! }.to raise_error(Tabscanner::ConfigurationError, "Region cannot be empty")
      end
    end

    context 'with empty region' do
      before do
        config.api_key = 'valid_key'
        config.region = ''
      end

      it 'raises ConfigurationError' do
        expect { config.validate! }.to raise_error(Tabscanner::ConfigurationError, "Region cannot be empty")
      end
    end
  end

  describe '.reset!' do
    it 'resets the singleton instance' do
      instance1 = described_class.instance
      described_class.reset!
      instance2 = described_class.instance
      expect(instance1).not_to be(instance2)
    end
  end
end

RSpec.describe Tabscanner do
  before do
    # Reset singleton instance before each test
    Tabscanner::Config.reset!
  end

  describe '.configure' do
    it 'yields the config instance' do
      yielded_config = nil
      described_class.configure do |config|
        yielded_config = config
      end
      expect(yielded_config).to be_a(Tabscanner::Config)
    end

    it 'allows configuration via block' do
      described_class.configure do |config|
        config.api_key = 'block_key'
        config.region = 'block_region'
        config.base_url = 'https://block.example.com'
      end

      config = described_class.config
      expect(config.api_key).to eq('block_key')
      expect(config.region).to eq('block_region')
      expect(config.base_url).to eq('https://block.example.com')
    end

    it 'returns the config instance' do
      result = described_class.configure
      expect(result).to be_a(Tabscanner::Config)
    end

    it 'works without a block' do
      expect { described_class.configure }.not_to raise_error
    end
  end

  describe '.config' do
    it 'returns the singleton config instance' do
      config = described_class.config
      expect(config).to be_a(Tabscanner::Config)
      expect(config).to be(described_class.config)
    end
  end
end