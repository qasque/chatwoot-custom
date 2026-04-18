# frozen_string_literal: true

class Telegram::SupportReportSender
  class DeliveryError < StandardError
    attr_reader :status_code

    def initialize(message, status_code: nil)
      super(message)
      @status_code = status_code
    end
  end

  TELEGRAM_API_BASE = 'https://api.telegram.org'.freeze

  def initialize(bot_token: ENV.fetch('TELEGRAM_BOT_TOKEN', ''), chat_id: ENV.fetch('TELEGRAM_CHAT_ID', ''))
    @bot_token = bot_token.to_s
    @chat_id = chat_id.to_s
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

    raise DeliveryError.new(
      "Telegram API failure: #{response.parsed_response&.dig('description') || response.body}",
      status_code: response.code
    )
  rescue Net::ReadTimeout, Net::OpenTimeout, SocketError => e
    raise DeliveryError.new("Telegram network error: #{e.message}")
  end

  private

  def validate_config!
    if @bot_token.blank? || @chat_id.blank?
      raise DeliveryError.new('TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be present')
    end
  end
end
