# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Telegram::SupportReportSender do
  let(:token) { 'test-token' }
  let(:chat_id) { '-100123' }
  let(:api_url) { %r{\Ahttps://api\.telegram\.org/bot#{token}/sendMessage\z} }

  describe '#perform' do
    it 'posts HTML message and returns response on success' do
      stub_request(:post, api_url).to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { ok: true, result: { message_id: 1 } }.to_json
      )

      response = described_class.new(bot_token: token, chat_id: chat_id).perform('<b>Hi</b>')

      expect(response).to be_success
      expect(response.code).to eq(200)
      expect(WebMock).to have_requested(:post, api_url).once
    end

    it 'raises DeliveryError with status on API error' do
      stub_request(:post, api_url).to_return(
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: { ok: false, description: 'Bad Request' }.to_json
      )

      sender = described_class.new(bot_token: token, chat_id: chat_id)
      error = nil
      begin
        sender.perform('x')
      rescue described_class::DeliveryError => e
        error = e
      end

      expect(error).to be_a(described_class::DeliveryError)
      expect(error.status_code).to eq(400)
    end

    it 'raises DeliveryError when token or chat is missing' do
      expect do
        described_class.new(bot_token: '', chat_id: chat_id).perform('x')
      end.to raise_error(described_class::DeliveryError, /TELEGRAM_REPORT_BOT_TOKEN/)
    end
  end
end
