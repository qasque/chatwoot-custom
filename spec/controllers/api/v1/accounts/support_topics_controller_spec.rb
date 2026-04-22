# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::SupportTopics', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  describe 'GET /api/v1/accounts/:account_id/support_topics' do
    it 'returns account scoped topics' do
      own_topic = SupportTopic.create!(account: account, name: 'VPN не подключается')
      other_account = create(:account)
      SupportTopic.create!(account: other_account, name: 'Чужая категория')

      get "/api/v1/accounts/#{account.id}/support_topics",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.fetch('payload').map { |topic| topic['id'] }
      expect(ids).to include(own_topic.id)
      expect(ids.length).to eq(1)
    end
  end
end
