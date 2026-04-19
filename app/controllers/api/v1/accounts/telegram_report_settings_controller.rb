# frozen_string_literal: true

class Api::V1::Accounts::TelegramReportSettingsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :ensure_setting_manageable!, only: %i[show update send_now]

  def show
    existing = TelegramReportSetting.first
    payload =
      if existing.present?
        serialize(existing)
      else
        serialize(
          TelegramReportSetting.new(
            schedule_hour: 9,
            schedule_minute: 0,
            timezone: ENV.fetch('REPORT_TIMEZONE', 'Europe/Moscow'),
            account_id: Current.account.id,
            inbox_ids: []
          )
        )
      end

    render json: {
      telegram_report_setting: payload,
      inboxes: inbox_options,
      timezones: ActiveSupport::TimeZone.all.map(&:name).sort
    }
  end

  def update
    setting = TelegramReportSetting.first_or_initialize
    setting.assign_attributes(setting_params.merge(account_id: Current.account.id))

    if setting.save
      render json: { telegram_report_setting: serialize(setting) }
    else
      render json: { errors: setting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def send_now
    outcome = validate_send_now
    return render_send_now_error(outcome[:alert]) if outcome[:alert]

    Support::DailyTelegramReportJob.perform_later(
      period_start_iso: outcome[:start_at].iso8601,
      period_end_iso: outcome[:end_at].iso8601,
      inbox_ids: outcome[:inbox_ids],
      account_id: outcome[:account].id
    )
    head :ok
  end

  private

  def ensure_setting_manageable!
    s = TelegramReportSetting.safe_first
    return if s.blank?
    return if s.account_id.blank? || s.account_id == Current.account.id

    render json: {
      error: 'Telegram report is linked to another account. Ask a super admin to reassign it.'
    }, status: :forbidden
    return
  end

  def serialize(setting)
    {
      id: setting.persisted? ? setting.id : nil,
      account_id: setting.account_id,
      schedule_hour: setting.schedule_hour,
      schedule_minute: setting.schedule_minute,
      timezone: setting.timezone,
      inbox_ids: setting.inbox_ids || []
    }
  end

  def inbox_options
    Current.account.inboxes.order(:name).map { |i| { id: i.id, name: i.name } }
  end

  def setting_params
    p = params.require(:telegram_report_setting).permit(
      :schedule_hour, :schedule_minute, :timezone, inbox_ids: []
    )
    p[:inbox_ids] = Array(p[:inbox_ids]).filter_map(&:presence).map(&:to_i)
    p
  end

  def validate_send_now
    account = Current.account
    start_at, end_at = parse_send_window
    return { alert: :invalid_period } if start_at.blank? || end_at.blank?
    return { alert: :end_before_start } if start_at >= end_at
    if (end_at - start_at) > TelegramReportSetting::MAX_MANUAL_RANGE_SECONDS
      return { alert: :period_too_long }
    end

    {
      account: account,
      start_at: start_at,
      end_at: end_at,
      inbox_ids: send_now_inbox_ids
    }
  end

  def send_now_inbox_ids
    raw = params[:inbox_ids]
    return nil if raw.nil?

    Array(raw).filter_map(&:presence).map(&:to_i)
  end

  def parse_send_window
    start_raw = params[:period_start].presence
    end_raw = params[:period_end].presence
    return [nil, nil] if start_raw.blank? || end_raw.blank?

    [Time.zone.parse(start_raw), Time.zone.parse(end_raw)]
  rescue ArgumentError, TypeError
    [nil, nil]
  end

  def render_send_now_error(key)
    render json: {
      error: I18n.t(key, scope: 'super_admin.telegram_report_settings.send_now')
    }, status: :unprocessable_entity
  end
end
