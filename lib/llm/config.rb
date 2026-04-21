require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil)
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key
        config.deepseek_api_key = api_key if config.respond_to?(:deepseek_api_key=)
        config.openai_api_base = api_base
        config.deepseek_api_base = api_base if config.respond_to?(:deepseek_api_base=)
      end

      yield context
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        if system_api_key.present?
          config.openai_api_key = system_api_key
          config.deepseek_api_key = system_api_key if config.respond_to?(:deepseek_api_key=)
        end

        if openai_endpoint.present?
          endpoint = openai_endpoint.chomp('/')
          config.openai_api_base = endpoint
          config.deepseek_api_base = endpoint if config.respond_to?(:deepseek_api_base=)
        end

        config.logger = Rails.logger
      end
    end

    def system_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    end

    def openai_endpoint
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    end
  end
end
