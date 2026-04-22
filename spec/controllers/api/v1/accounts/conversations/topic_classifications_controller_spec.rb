# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Conversations::TopicClassification', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }

  describe 'GET /api/v1/accounts/:account_id/conversations/:conversation_id/topic_classification' do
    it 'returns current topic and available topics' do
      topic = SupportTopic.create!(account: account, name: 'Не подключается VPN')
      conversation.update!(support_topic: topic)

      get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/topic_classification",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('support_topic', 'id')).to eq(topic.id)
      expect(response.parsed_body.fetch('topics').map { |t| t['id'] }).to include(topic.id)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/conversations/:conversation_id/topic_classification' do
    it 'reuses existing topic by id' do
      topic = SupportTopic.create!(account: account, name: 'Проблема с оплатой')

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/topic_classification",
           params: { existing_topic_id: topic.id },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(conversation.reload.support_topic_id).to eq(topic.id)
    end

    it 'creates and assigns topic by name' do
      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/topic_classification",
           params: { topic_name: 'Скорость соединения' },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:ok)
      topic = conversation.reload.support_topic
      expect(topic).to be_present
      expect(topic.name).to eq('Скорость соединения')
    end
  end
end
