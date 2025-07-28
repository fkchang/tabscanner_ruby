# frozen_string_literal: true

require 'logger'

module Tabscanner
  # Configuration class implementing singleton pattern
  # 
  # This class manages global configuration for the Tabscanner gem.
  # It implements the singleton pattern to ensure consistent configuration
  # across the entire application.
  #
  # @example Basic configuration
  #   Tabscanner.configure do |config|
  #     config.api_key = 'your-key'
  #     config.region = 'us'
  #   end
  #
  # @example Debug configuration
  #   Tabscanner.configure do |config|
  #     config.api_key = 'your-key'
  #     config.debug = true
  #     config.logger = Logger.new(STDOUT)
  #   end
  #
  # @example Access current configuration
  #   Tabscanner.config.api_key
  class Config
    # @!attribute [rw] api_key
    #   @return [String, nil] The API key for Tabscanner service
    # @!attribute [rw] region
    #   @return [String] The region for API calls (default: 'us')
    # @!attribute [rw] base_url
    #   @return [String, nil] Override base URL for API calls
    # @!attribute [rw] debug
    #   @return [Boolean] Enable debug logging and enhanced error details (default: false)
    # @!attribute [rw] logger
    #   @return [Logger] Logger instance for debug output (default: Logger.new(STDOUT))
    attr_accessor :api_key, :region, :base_url, :debug, :logger

    # Initialize configuration with default values from environment variables
    def initialize
      @api_key = ENV['TABSCANNER_API_KEY']
      @region = ENV['TABSCANNER_REGION'] || 'us'
      @base_url = ENV['TABSCANNER_BASE_URL']
      @debug = ENV['TABSCANNER_DEBUG'] == 'true' || false
      @logger = nil # Will be created lazily in logger method
    end

    # Thread-safe singleton instance access
    # @return [Config] the singleton instance
    def self.instance
      @instance ||= new
    end

    # Reset the singleton instance (primarily for testing)
    # @api private
    def self.reset!
      @instance = nil
    end

    # Get or create the logger instance
    # @return [Logger] Logger instance for debug output
    def logger
      @logger ||= Logger.new(STDOUT).tap do |log|
        log.level = debug? ? Logger::DEBUG : Logger::WARN
        log.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime}] #{severity} -- Tabscanner: #{msg}\n"
        end
      end
    end

    # Check if debug mode is enabled
    # @return [Boolean] true if debug mode is enabled
    def debug?
      !!@debug
    end

    # Validate that required configuration is present
    # @raise [ConfigurationError] if required configuration is missing
    def validate!
      raise Tabscanner::ConfigurationError, "API key is required" if api_key.nil? || api_key.empty?
      raise Tabscanner::ConfigurationError, "Region cannot be empty" if region.nil? || region.empty?
    end

    private_class_method :new
  end

  # Configure the gem with a block
  # @yield [Config] the configuration instance
  # @return [Config] the configuration instance
  def self.configure
    yield(Config.instance) if block_given?
    Config.instance
  end

  # Access the current configuration
  # @return [Config] the singleton configuration instance
  def self.config
    Config.instance
  end
end