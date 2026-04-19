# frozen_string_literal: true

class Support::TelegramReportScheduleSync
  CRON_JOB_NAME = 'support_daily_telegram_report_job'

  def self.apply_from_database
    return unless table_ready?

    setting = TelegramReportSetting.first
    apply_from_model(setting) if setting.present?
  end

  def self.apply_from_model(setting)
    return if setting.blank?
    return unless defined?(Sidekiq::Cron::Job)

    job = Sidekiq::Cron::Job.find(CRON_JOB_NAME)
    return if job.blank?

    job.cron = "#{setting.schedule_minute} #{setting.schedule_hour} * * *"
    job.tz = setting.timezone.presence || 'Europe/Moscow'
    job.save
  rescue StandardError => e
    Rails.logger.warn("[TelegramReportScheduleSync] skipped: #{e.class}: #{e.message}")
  end

  def self.table_ready?
    TelegramReportSetting.connection.data_source_exists?(TelegramReportSetting.table_name)
  rescue StandardError
    false
  end
end
