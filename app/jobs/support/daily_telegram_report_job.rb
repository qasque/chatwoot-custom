# frozen_string_literal: true

class Support::DailyTelegramReportJob < ApplicationJob
  queue_as :scheduled_jobs

  BASE_RETRY_SECONDS = 30
  MAX_RETRY_SECONDS = 300

  DEFAULT_PAYLOAD = {
    report_end_iso: nil,
    period_start_iso: nil,
    period_end_iso: nil,
    inbox_ids: nil,
    account_id: nil,
    attempt: 0
  }.freeze

  def perform(**payload)
    @opts = DEFAULT_PAYLOAD.merge(payload.deep_symbolize_keys)
    dispatch_report
  rescue Telegram::SupportReportSender::DeliveryError => e
    retry_delivery(anchor: @anchor, attempt: @opts[:attempt], error: e, **@opts.except(:attempt))
  end

  private

  def dispatch_report
    setting = TelegramReportSetting.safe_first
    timezone = (setting&.timezone).presence || ENV.fetch('REPORT_TIMEZONE', 'Europe/Moscow')

    @period_start, @period_end, @anchor = compute_period(
      @opts[:report_end_iso], @opts[:period_start_iso], @opts[:period_end_iso], timezone
    )
    return log_invalid_report_period if @period_start.blank? || @period_end.blank?

    account = resolve_account(@opts[:account_id], setting)
    return if account.blank?

    log_successful_delivery(account, timezone, setting)
  end

  def log_invalid_report_period
    Rails.logger.warn('[SupportDailyReport] invalid or empty period, skipping')
  end

  def log_successful_delivery(account, timezone, setting)
    inbox_ids = coerce_inbox_ids(@opts[:inbox_ids], setting)
    response = deliver_report(account, @period_start, @period_end, timezone, inbox_ids)

    Rails.logger.info(
      "[SupportDailyReport] sent account_id=#{account.id} status=#{response.code} " \
      "attempt=#{@opts[:attempt]} period_end=#{@period_end.iso8601}"
    )
  end

  def deliver_report(account, period_start, period_end, timezone, inbox_ids)
    report_text = Support::DailyTelegramReportBuilder.new(
      account: account,
      period_start: period_start,
      period_end: period_end,
      inbox_ids: inbox_ids,
      display_timezone: timezone
    ).perform

    Telegram::SupportReportSender.new.perform(report_text)
  end

  def compute_period(report_end_iso, period_start_iso, period_end_iso, timezone)
    if period_start_iso.present? && period_end_iso.present?
      manual_period_bounds(period_start_iso, period_end_iso, timezone)
    else
      report_end = resolve_report_end(report_end_iso, timezone)
      [report_end - 24.hours, report_end, report_end]
    end
  end

  def manual_period_bounds(period_start_iso, period_end_iso, timezone)
    p_start = parse_in_zone(period_start_iso, timezone)
    p_end = parse_in_zone(period_end_iso, timezone)
    return [nil, nil, nil] if p_start.blank? || p_end.blank?
    return [nil, nil, nil] if p_start >= p_end

    return too_long_period if (p_end - p_start) > TelegramReportSetting::MAX_MANUAL_RANGE_SECONDS

    [p_start, p_end, p_end]
  end

  def too_long_period
    Rails.logger.warn('[SupportDailyReport] period too long, skipping')
    [nil, nil, nil]
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
    account_from_id(explicit_account_id) ||
      account_from_id(setting&.account_id) ||
      account_from_id(ENV.fetch('TELEGRAM_REPORT_ACCOUNT_ID', '')) ||
      Account.order(:id).first
  end

  def account_from_id(raw)
    id = raw.to_i
    return if id <= 0

    Account.find_by(id: id)
  end

  def coerce_inbox_ids(explicit, setting)
    return normalize_id_array(explicit).presence unless explicit.nil?

    normalize_id_array(setting&.inbox_ids).presence
  end

  def normalize_id_array(raw)
    Array(raw).filter_map(&:presence).map(&:to_i).uniq.select(&:positive?)
  end

  def retry_delivery(anchor:, attempt:, error:, **retry_kwargs)
    unless retryable_delivery_error?(error)
      Rails.logger.warn(
        "[SupportDailyReport] not_retrying status=#{error.status_code || 'n/a'} error=#{error.message}"
      )
      return
    end

    enqueue_delivery_retry(anchor, attempt, error, retry_kwargs)
  end

  def enqueue_delivery_retry(anchor, attempt, error, retry_kwargs)
    next_attempt = attempt + 1
    delay = [BASE_RETRY_SECONDS * (2**attempt), MAX_RETRY_SECONDS].min.seconds

    Rails.logger.error(
      "[SupportDailyReport] send_failed status=#{error.status_code || 'n/a'} " \
      "attempt=#{next_attempt} retry_in=#{delay.to_i}s error=#{error.message}"
    )

    self.class.set(wait: delay).perform_later(
      **retry_kwargs,
      report_end_iso: anchor.iso8601,
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
