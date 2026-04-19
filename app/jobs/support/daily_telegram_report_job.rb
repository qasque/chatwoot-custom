# frozen_string_literal: true

class Support::DailyTelegramReportJob < ApplicationJob
  queue_as :scheduled_jobs

  BASE_RETRY_SECONDS = 30
  MAX_RETRY_SECONDS = 300

  def perform(report_end_iso: nil, period_start_iso: nil, period_end_iso: nil, inbox_ids: nil, account_id: nil, attempt: 0)
    setting = TelegramReportSetting.safe_first
    timezone = (setting&.timezone).presence || ENV.fetch('REPORT_TIMEZONE', 'Europe/Moscow')

    period_start, period_end, anchor_for_retry = compute_period(
      report_end_iso, period_start_iso, period_end_iso, timezone
    )
    if period_start.blank? || period_end.blank?
      Rails.logger.warn('[SupportDailyReport] invalid or empty period, skipping')
      return
    end

    account = resolve_account(account_id, setting)
    return if account.blank?

    effective_inbox_ids = coerce_inbox_ids(inbox_ids, setting)

    report_text = Support::DailyTelegramReportBuilder.new(
      account: account,
      period_start: period_start,
      period_end: period_end,
      inbox_ids: effective_inbox_ids,
      display_timezone: timezone
    ).perform

    response = Telegram::SupportReportSender.new.perform(report_text)

    Rails.logger.info(
      "[SupportDailyReport] sent account_id=#{account.id} status=#{response.code} " \
      "attempt=#{attempt} period_end=#{period_end.iso8601}"
    )
  rescue Telegram::SupportReportSender::DeliveryError => e
    retry_delivery(
      anchor: anchor_for_retry,
      period_start_iso: period_start_iso,
      period_end_iso: period_end_iso,
      inbox_ids: inbox_ids,
      account_id: account_id,
      attempt: attempt,
      error: e
    )
  end

  private

  def compute_period(report_end_iso, period_start_iso, period_end_iso, timezone)
    if period_start_iso.present? && period_end_iso.present?
      p_start = parse_in_zone(period_start_iso, timezone)
      p_end = parse_in_zone(period_end_iso, timezone)
      return [nil, nil, nil] if p_start.blank? || p_end.blank?
      return [nil, nil, nil] if p_start >= p_end
      if (p_end - p_start) > TelegramReportSetting::MAX_MANUAL_RANGE_SECONDS
        Rails.logger.warn('[SupportDailyReport] period too long, skipping')
        return [nil, nil, nil]
      end

      [p_start, p_end, p_end]
    else
      report_end = resolve_report_end(report_end_iso, timezone)
      [report_end - 24.hours, report_end, report_end]
    end
  end

  def parse_in_zone(iso, timezone)
    Time.zone.parse(iso)&.in_time_zone(timezone)
  end

  def resolve_report_end(report_end_iso, timezone)
    if report_end_iso.present?
      parsed = Time.zone.parse(report_end_iso)
      return parsed.in_time_zone(timezone) if parsed.present?
    end

    Time.current.in_time_zone(timezone).change(sec: 0)
  end

  def resolve_account(explicit_account_id, setting)
    aid = explicit_account_id.to_i if explicit_account_id.present?
    aid ||= setting.account_id if setting&.account_id.present?
    return Account.find_by(id: aid) if aid.present? && aid.positive?

    env_id = ENV.fetch('TELEGRAM_REPORT_ACCOUNT_ID', '').to_i
    return Account.find_by(id: env_id) if env_id.positive?

    Account.order(:id).first
  end

  def coerce_inbox_ids(explicit, setting)
    unless explicit.nil?
      return normalize_id_array(explicit).presence
    end

    normalize_id_array(setting&.inbox_ids).presence
  end

  def normalize_id_array(raw)
    Array(raw).map(&:presence).compact.map(&:to_i).uniq.select(&:positive?)
  end

  def retry_delivery(anchor:, period_start_iso:, period_end_iso:, inbox_ids:, account_id:, attempt:, error:)
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

    self.class.set(wait: delay).perform_later(
      report_end_iso: anchor.iso8601,
      period_start_iso: period_start_iso,
      period_end_iso: period_end_iso,
      inbox_ids: inbox_ids,
      account_id: account_id,
      attempt: next_attempt
    )
  end

  def retryable_delivery_error?(error)
    msg = error.message.to_s
    return false if msg.include?('TELEGRAM_REPORT_BOT_TOKEN and TELEGRAM_REPORT_CHAT_ID must be present')
    return false if msg.include?('TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be present')

    code = error.status_code.to_i
    return false if [400, 401, 403].include?(code)

    true
  end
end
