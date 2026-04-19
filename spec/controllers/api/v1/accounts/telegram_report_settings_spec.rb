# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::TelegramReportSettings', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/:account_id/telegram_report_setting' do
    it 'returns 401 for agent' do
      get "/api/v1/accounts/#{account.id}/telegram_report_setting",
          headers: agent.create_new_auth_token,
          as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns defaults when no row exists' do
      get "/api/v1/accounts/#{account.id}/telegram_report_setting",
          headers: admin.create_new_auth_token,
          as: :json
      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['telegram_report_setting']['account_id']).to eq(account.id)
      expect(body['inboxes']).to be_an(Array)
      expect(body['timezones']).to include('Europe/Moscow')
    end

    it 'returns 403 when report is linked to another account' do
      other = create(:account)
      TelegramReportSetting.create!(
        account_id: other.id,
        schedule_hour: 8,
        schedule_minute: 0,
        timezone: 'Europe/Moscow',
        inbox_ids: []
      )

      get "/api/v1/accounts/#{account.id}/telegram_report_setting",
          headers: admin.create_new_auth_token,
          as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/telegram_report_setting' do
    it 'creates row scoped to current account' do
      expect do
        patch "/api/v1/accounts/#{account.id}/telegram_report_setting",
              params: {
                telegram_report_setting: {
                  schedule_hour: 11,
                  schedule_minute: 15,
                  timezone: 'Europe/Moscow',
                  inbox_ids: []
                }
              },
              headers: admin.create_new_auth_token,
              as: :json
      end.to change(TelegramReportSetting, :count).by(1)

      expect(response).to have_http_status(:success)
      s = TelegramReportSetting.first
      expect(s.account_id).to eq(account.id)
      expect(s.schedule_hour).to eq(11)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/telegram_report_setting/send_now' do
    before { clear_enqueued_jobs }

    it 'enqueues job for current account' do
      inbox = create(:inbox, account: account)
      start_at = Time.zone.parse('2026-04-10 08:00')
      end_at = Time.zone.parse('2026-04-11 08:00')

      expect do
        post "/api/v1/accounts/#{account.id}/telegram_report_setting/send_now",
             params: {
               period_start: start_at.iso8601,
               period_end: end_at.iso8601,
               inbox_ids: [inbox.id]
             },
             headers: admin.create_new_auth_token,
             as: :json
      end.to have_enqueued_job(Support::DailyTelegramReportJob)

      expect(response).to have_http_status(:ok)
      job = ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find { |j| j[:job] == Support::DailyTelegramReportJob }
      payload = job[:args].first.with_indifferent_access
      expect(payload[:account_id]).to eq(account.id)
      expect(payload[:inbox_ids]).to eq([inbox.id])
    end
  end
end
