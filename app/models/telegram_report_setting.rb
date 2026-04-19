# frozen_string_literal: true

class TelegramReportSetting < ApplicationRecord
  MAX_MANUAL_RANGE_SECONDS = 31.days.to_i

  validates :schedule_hour, inclusion: { in: 0..23 }
  validates :schedule_minute, inclusion: { in: 0..59 }
  validate :timezone_must_be_recognized
  validate :inbox_ids_belong_to_account, if: -> { account_id.present? && inbox_ids.present? }

  after_commit :sync_sidekiq_cron, on: %i[create update]

  def inbox_ids
    super || []
  end

  def filtered_inbox_ids
    inbox_ids.presence
  end

  def self.safe_first
    return unless connection.data_source_exists?(table_name)

    first
  rescue StandardError
    nil
  end

  private

  def timezone_must_be_recognized
    return if timezone.blank?

    errors.add(:timezone, 'is not a valid time zone') if ActiveSupport::TimeZone[timezone].blank?
  end

  def inbox_ids_belong_to_account
    valid = Account.find_by(id: account_id)&.inboxes&.pluck(:id).to_a
    bad = Array(inbox_ids).map(&:to_i) - valid
    errors.add(:inbox_ids, "unknown for account: #{bad.join(', ')}") if bad.any?
  end

  def sync_sidekiq_cron
    Support::TelegramReportScheduleSync.apply_from_model(self)
  end
end
