# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Support::DailyTelegramReportJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:report_end) { Time.zone.parse('2026-04-15 09:00:00') }
  let(:sender) { instance_double(Telegram::SupportReportSender) }
  let(:http_response) do
    instance_double(HTTParty::Response, success?: true, code: 200, parsed_response: { 'ok' => true })
  end

  def enqueued_daily_reports
    ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == described_class }
  end

  before do
    account
    allow(Telegram::SupportReportSender).to receive(:new).and_return(sender)
    allow(sender).to receive(:perform).and_return(http_response)
  end

  after do
    clear_enqueued_jobs
  end

  it 'sends report for resolved window' do
    expect(sender).to receive(:perform).with(a_string_including('Техподдержка'))

    travel_to report_end do
      described_class.perform_now
    end
  end

  it 'schedules retry on retryable delivery errors' do
    allow(sender).to receive(:perform).and_raise(
      Telegram::SupportReportSender::DeliveryError.new('temporary', status_code: 502)
    )

    expect do
      travel_to report_end do
        described_class.perform_now
      end
    end.to change(enqueued_daily_reports, :size).by(1)

    payload = enqueued_daily_reports.last[:args].first.with_indifferent_access
    expect(payload[:attempt]).to eq(1)
    expect(payload[:report_end_iso]).to eq(report_end.iso8601)
  end

  it 'does not schedule retry on missing telegram configuration' do
    allow(sender).to receive(:perform).and_raise(
      Telegram::SupportReportSender::DeliveryError.new(
        'TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be present'
      )
    )

    expect do
      travel_to report_end do
        described_class.perform_now
      end
    end.not_to(change(enqueued_daily_reports, :size))
  end

  it 'does not schedule retry on HTTP 400 from Telegram' do
    allow(sender).to receive(:perform).and_raise(
      Telegram::SupportReportSender::DeliveryError.new('bad chat', status_code: 400)
    )

    expect do
      travel_to report_end do
        described_class.perform_now
      end
    end.not_to(change(enqueued_daily_reports, :size))
  end
end
