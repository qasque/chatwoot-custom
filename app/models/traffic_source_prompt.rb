class TrafficSourcePrompt < ApplicationRecord
  ALLOWED_EXTENSIONS = %w[.txt .doc .docx .pdf].freeze

  belongs_to :account
  belongs_to :inbox

  validates :source_id, presence: true
  validates :file_name, presence: true
  validates :prompt_text, presence: true
  validates :source_id, uniqueness: { scope: :inbox_id }

  scope :for_source, lambda { |account_id:, inbox_id:, source_id:|
    where(account_id: account_id, inbox_id: inbox_id, source_id: source_id)
  }
end
