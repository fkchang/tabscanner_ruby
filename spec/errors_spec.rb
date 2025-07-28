# frozen_string_literal: true

RSpec.describe "Tabscanner Error Classes" do
  describe Tabscanner::Error do
    it 'is a StandardError subclass' do
      expect(Tabscanner::Error.superclass).to eq(StandardError)
    end

    it 'can be raised with a message' do
      expect { raise Tabscanner::Error, "test message" }
        .to raise_error(Tabscanner::Error, "test message")
    end
  end

  describe Tabscanner::ConfigurationError do
    it 'is a Tabscanner::Error subclass' do
      expect(Tabscanner::ConfigurationError.superclass).to eq(Tabscanner::Error)
    end

    it 'can be raised with a message' do
      expect { raise Tabscanner::ConfigurationError, "config error" }
        .to raise_error(Tabscanner::ConfigurationError, "config error")
    end
  end
end