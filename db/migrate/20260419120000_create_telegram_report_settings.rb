# frozen_string_literal: true

class CreateTelegramReportSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :telegram_report_settings do |t|
      t.bigint :account_id
      t.integer :schedule_hour, null: false, default: 9
      t.integer :schedule_minute, null: false, default: 0
      t.string :timezone, null: false, default: 'Europe/Moscow'
      t.jsonb :inbox_ids, null: false, default: []

      t.timestamps
    end
  end
end
