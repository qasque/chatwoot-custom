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
      redirect_to super_admin_telegram_report_setting_path, notice: 'Telegram report settings saved.'
    else
      @accounts = Account.order(:name)
      @inboxes = inboxes_for(@setting.account_id)
      render :show, status: :unprocessable_entity
    end
  end

  def send_now
    account = Account.find_by(id: params[:account_id])
    if account.blank?
      redirect_to super_admin_telegram_report_setting_path, alert: 'Select a valid account.'
      return
    end

    start_at, end_at = parse_send_window
    if start_at.blank? || end_at.blank?
      redirect_to super_admin_telegram_report_setting_path, alert: 'Enter a valid period (start and end).'
      return
    end

    if start_at >= end_at
      redirect_to super_admin_telegram_report_setting_path, alert: 'End time must be after start time.'
      return
    end

    if (end_at - start_at) > TelegramReportSetting::MAX_MANUAL_RANGE_SECONDS
      redirect_to super_admin_telegram_report_setting_path, alert: 'Period is too long (maximum 31 days).'
      return
    end

    inbox_ids = Array(params[:inbox_ids]).map(&:presence).compact.map(&:to_i)

    Support::DailyTelegramReportJob.perform_later(
      period_start_iso: start_at.iso8601,
      period_end_iso: end_at.iso8601,
      inbox_ids: inbox_ids,
      account_id: account.id
    )

    redirect_to super_admin_telegram_report_setting_path,
                notice: 'Report queued. It will be sent to Telegram shortly.'
  end

  private

  def setting_params
    p = params.require(:telegram_report_setting).permit(
      :account_id, :schedule_hour, :schedule_minute, :timezone, inbox_ids: []
    )
    p[:account_id] = nil if p[:account_id].blank?
    p[:inbox_ids] = Array(p[:inbox_ids]).map(&:presence).compact.map(&:to_i)
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
