# frozen_string_literal: true

class Support::DailyTelegramReportJob < ApplicationJob
  queue_as :scheduled_jobs

  BASE_RETRY_SECONDS = 30
  MAX_RETRY_SECONDS = 300

  def perform(report_end_iso: nil, attempt: 0)
    report_end = resolve_report_end(report_end_iso)
    account = resolve_account
    return if account.blank?

    report_text = Support::DailyTelegramReportBuilder.new(
      account: account,
      period_start: report_end - 24.hours,
      period_end: report_end
    ).perform

    response = Telegram::SupportReportSender.new.perform(report_text)

    Rails.logger.info(
      "[SupportDailyReport] sent account_id=#{account.id} status=#{response.code} " \
      "attempt=#{attempt} period_end=#{report_end.iso8601}"
    )
  rescue Telegram::SupportReportSender::DeliveryError => e
    retry_delivery(report_end, attempt, e)
  end

  private

  def resolve_report_end(report_end_iso)
    timezone = ENV.fetch('REPORT_TIMEZONE', 'Europe/Moscow')
    if report_end_iso.present?
      parsed = Time.zone.parse(report_end_iso)
      return parsed.in_time_zone(timezone) if parsed.present?
    end

    Time.current.in_time_zone(timezone).change(sec: 0)
  end

  def resolve_account
    account_id = ENV.fetch('TELEGRAM_REPORT_ACCOUNT_ID', '').to_i
    return Account.find_by(id: account_id) if account_id.positive?

    Account.order(:id).first
  end

  def retry_delivery(report_end, attempt, error)
    unless retryable_delivery_error?(error)
      Rails.logger.warn(
        "[SupportDailyReport] not_retrying status=#{error.status_code || 'n/a'} error=#{error.message}"
      )
      return
    end

    next_attempt = attempt + 1
    delay = [BASE_RETRY_SECONDS * (2**attempt), MAX_RETRY_SECONDS].min.seconds

    Rails.logger.error(
      "[SupportDailyReport] send_failed status=#{error.status_code || 'n/a'} " \
      "attempt=#{next_attempt} retry_in=#{delay.to_i}s error=#{error.message}"
    )

    self.class.set(wait: delay).perform_later(report_end_iso: report_end.iso8601, attempt: next_attempt)
  end

  def retryable_delivery_error?(error)
    return false if error.message.to_s.include?('TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be present')

    code = error.status_code.to_i
    return false if [400, 401, 403].include?(code)

    true
  end
end
