# frozen_string_literal: true

class SuperAdmin::TelegramReportSettingsController < SuperAdmin::ApplicationController
  def show
    @setting = TelegramReportSetting.first_or_initialize(
      schedule_hour: 9,
      schedule_minute: 0,
      timezone: ENV.fetch('REPORT_TIMEZONE', 'Europe/Moscow')
    )
    if @setting.new_record?
      eid = ENV['TELEGRAM_REPORT_ACCOUNT_ID'].to_i
      @setting.account_id = eid if eid.positive?
    end
    @accounts = Account.order(:name)
    preview_account_id = params[:account_id].presence&.to_i || @setting.account_id
    @inboxes = inboxes_for(preview_account_id)
  end

  def update
    @setting = TelegramReportSetting.first_or_initialize
    @setting.assign_attributes(setting_params)

    if @setting.save
      redirect_to super_admin_telegram_report_setting_path,
                  notice: I18n.t('super_admin.telegram_report_settings.saved')
    else
      @accounts = Account.order(:name)
      @inboxes = inboxes_for(@setting.account_id)
      render :show, status: :unprocessable_entity
    end
  end

  def send_now
    outcome = validate_send_now
    return redirect_send_now_alert(outcome[:alert]) if outcome[:alert]

    enqueue_send_now(outcome)
    redirect_to super_admin_telegram_report_setting_path,
                notice: I18n.t('super_admin.telegram_report_settings.send_now_queued')
  end

  private

  def validate_send_now
    account = Account.find_by(id: params[:account_id])
    return { alert: :select_account } if account.blank?

    start_at, end_at = parse_send_window
    return { alert: :invalid_period } if start_at.blank? || end_at.blank?
    return { alert: :end_before_start } if start_at >= end_at
    return { alert: :period_too_long } if (end_at - start_at) > TelegramReportSetting::MAX_MANUAL_RANGE_SECONDS

    {
      account: account,
      start_at: start_at,
      end_at: end_at,
      inbox_ids: send_now_inbox_ids
    }
  end

  def enqueue_send_now(outcome)
    Support::DailyTelegramReportJob.perform_later(
      period_start_iso: outcome[:start_at].iso8601,
      period_end_iso: outcome[:end_at].iso8601,
      inbox_ids: outcome[:inbox_ids],
      account_id: outcome[:account].id
    )
  end

  def redirect_send_now_alert(key)
    redirect_to super_admin_telegram_report_setting_path,
                alert: I18n.t(key, scope: 'super_admin.telegram_report_settings.send_now')
  end

  def send_now_inbox_ids
    Array(params[:inbox_ids]).filter_map(&:presence).map(&:to_i)
  end

  def setting_params
    p = params.require(:telegram_report_setting).permit(
      :account_id, :schedule_hour, :schedule_minute, :timezone, inbox_ids: []
    )
    p[:account_id] = nil if p[:account_id].blank?
    p[:inbox_ids] = Array(p[:inbox_ids]).filter_map(&:presence).map(&:to_i)
    p
  end

  def inboxes_for(account_id)
    account = Account.find_by(id: account_id)
    account ? account.inboxes.order(:name) : Inbox.none
  end

  def parse_send_window
    start_raw = params[:period_start].presence
    end_raw = params[:period_end].presence
    return [nil, nil] if start_raw.blank? || end_raw.blank?

    [Time.zone.parse(start_raw), Time.zone.parse(end_raw)]
  rescue ArgumentError, TypeError
    [nil, nil]
  end
end
