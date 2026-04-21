# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Inboxes::TrafficSourcePrompts', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }

  describe 'GET /api/v1/accounts/:account_id/inboxes/:inbox_id/traffic_source_prompts/current' do
    it 'returns prompt for source' do
      create(:traffic_source_prompt, account: account, inbox: inbox, source_id: 'src-1', file_name: 'a.txt')

      get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/traffic_source_prompts/current",
          params: { source_id: 'src-1' },
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('payload', 'source_id')).to eq('src-1')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/inboxes/:inbox_id/traffic_source_prompts' do
    it 'creates or replaces prompt from txt file' do
      file = fixture_file_upload('files/valid.txt', 'text/plain')

      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/traffic_source_prompts",
           params: { source_id: 'src-2', file: file },
           headers: admin.create_new_auth_token

      expect(response).to have_http_status(:ok)
      prompt = TrafficSourcePrompt.find_by!(inbox_id: inbox.id, source_id: 'src-2')
      expect(prompt.prompt_text).to include('hello')
      expect(prompt.file_name).to eq('valid.txt')
    end

    it 'creates default inbox prompt when source_id is omitted' do
      file = fixture_file_upload('files/valid.txt', 'text/plain')

      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/traffic_source_prompts",
           params: { file: file },
           headers: admin.create_new_auth_token

      expect(response).to have_http_status(:ok)
      prompt = TrafficSourcePrompt.find_by!(inbox_id: inbox.id, source_id: nil)
      expect(prompt.prompt_text).to include('hello')
    end
  end

  describe 'GET /api/v1/accounts/:account_id/inboxes/:inbox_id/traffic_source_prompts/current without source' do
    it 'returns default inbox prompt' do
      create(:traffic_source_prompt, account: account, inbox: inbox, source_id: nil, file_name: 'default.txt')

      get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/traffic_source_prompts/current",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('payload', 'file_name')).to eq('default.txt')
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/inboxes/:inbox_id/traffic_source_prompts' do
    it 'deletes prompt for source' do
      create(:traffic_source_prompt, account: account, inbox: inbox, source_id: 'src-1', file_name: 'a.txt')

      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/traffic_source_prompts",
             params: { source_id: 'src-1' },
             headers: admin.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:no_content)
      expect(TrafficSourcePrompt.find_by(inbox_id: inbox.id, source_id: 'src-1')).to be_nil
    end

    it 'deletes default inbox prompt when source_id is omitted' do
      create(:traffic_source_prompt, account: account, inbox: inbox, source_id: nil, file_name: 'default.txt')

      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/traffic_source_prompts",
             headers: admin.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:no_content)
      expect(TrafficSourcePrompt.find_by(inbox_id: inbox.id, source_id: nil)).to be_nil
    end
  end
end
