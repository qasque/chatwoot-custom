# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SuperAdmin::TelegramReportSettingsController, type: :request do
  include ActiveJob::TestHelper

  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account) }

  describe 'GET /super_admin/telegram_report_setting' do
    it 'redirects when not signed in' do
      get '/super_admin/telegram_report_setting'
      expect(response).to have_http_status(:redirect)
    end

    it 'renders for super admin' do
      sign_in(super_admin, scope: :super_admin)
      get '/super_admin/telegram_report_setting'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /super_admin/telegram_report_setting' do
    before { sign_in(super_admin, scope: :super_admin) }

    it 'creates settings and redirects' do
      expect do
        patch '/super_admin/telegram_report_setting', params: {
          telegram_report_setting: {
            account_id: account.id,
            schedule_hour: 10,
            schedule_minute: 30,
            timezone: 'Europe/Moscow',
            inbox_ids: ['']
          }
        }
      end.to change(TelegramReportSetting, :count).by(1)

      expect(response).to redirect_to('/super_admin/telegram_report_setting')
      s = TelegramReportSetting.first
      expect(s.schedule_hour).to eq(10)
      expect(s.schedule_minute).to eq(30)
      expect(s.inbox_ids).to eq([])
    end
  end

  describe 'POST /super_admin/telegram_report_setting/send_now' do
    before do
      sign_in(super_admin, scope: :super_admin)
      clear_enqueued_jobs
    end

    it 'enqueues report job with period and account' do
      inbox = create(:inbox, account: account)
      start_at = Time.zone.parse('2026-04-10 08:00')
      end_at = Time.zone.parse('2026-04-11 08:00')

      expect do
        post '/super_admin/telegram_report_setting/send_now', params: {
          account_id: account.id,
          period_start: start_at.strftime('%Y-%m-%dT%H:%M'),
          period_end: end_at.strftime('%Y-%m-%dT%H:%M'),
          inbox_ids: [inbox.id]
        }
      end.to have_enqueued_job(Support::DailyTelegramReportJob)

      expect(response).to redirect_to('/super_admin/telegram_report_setting')

      job = ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find { |j| j[:job] == Support::DailyTelegramReportJob }
      expect(job).to be_present
      payload = job[:args].first.with_indifferent_access
      expect(payload[:account_id]).to eq(account.id)
      expect(Time.zone.parse(payload[:period_start_iso].to_s)).to be_within(1.second).of(start_at)
      expect(Time.zone.parse(payload[:period_end_iso].to_s)).to be_within(1.second).of(end_at)
      expect(payload[:inbox_ids]).to eq([inbox.id])
    end
  end
end
