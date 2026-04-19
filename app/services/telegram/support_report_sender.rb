# frozen_string_literal: true

class Telegram::SupportReportSender
  class DeliveryError < StandardError
    attr_reader :status_code

    def initialize(message, status_code: nil)
      super(message)
      @status_code = status_code
    end
  end

  TELEGRAM_API_BASE = 'https://api.telegram.org'

  # Prefer TELEGRAM_REPORT_* so a second support bot can keep TELEGRAM_BOT_TOKEN for other integrations.
  def self.report_bot_token
    ENV['TELEGRAM_REPORT_BOT_TOKEN'].presence || ENV.fetch('TELEGRAM_BOT_TOKEN', '')
  end

  def self.report_chat_id
    ENV['TELEGRAM_REPORT_CHAT_ID'].presence || ENV.fetch('TELEGRAM_CHAT_ID', '')
  end

  def initialize(bot_token: nil, chat_id: nil)
    @bot_token = (bot_token.presence || self.class.report_bot_token).to_s
    @chat_id = (chat_id.presence || self.class.report_chat_id).to_s
  end

  def perform(html_text)
    validate_config!

    response = HTTParty.post(
      "#{TELEGRAM_API_BASE}/bot#{@bot_token}/sendMessage",
      body: {
        chat_id: @chat_id,
        text: html_text,
        parse_mode: 'HTML',
        disable_web_page_preview: true
      },
      timeout: 15
    )

    return response if response.success? && response.parsed_response['ok'] == true

    description = response.parsed_response&.dig('description') || response.body
    error = DeliveryError.new("Telegram API failure: #{description}", status_code: response.code)
    raise error
  rescue Net::ReadTimeout, Net::OpenTimeout, SocketError => e
    raise DeliveryError, "Telegram network error: #{e.message}"
  end

  private

  def validate_config!
    return if @bot_token.present? && @chat_id.present?

    raise DeliveryError,
          'TELEGRAM_REPORT_BOT_TOKEN and TELEGRAM_REPORT_CHAT_ID must be present ' \
          '(or legacy TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)'
  end
end
