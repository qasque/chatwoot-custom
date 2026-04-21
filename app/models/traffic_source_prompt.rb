class TrafficSourcePrompt < ApplicationRecord
  ALLOWED_EXTENSIONS = %w[.txt .doc .docx .pdf].freeze
  DEFAULT_SOURCE_IDS = %w[__inbox_default__ default *].freeze

  belongs_to :account
  belongs_to :inbox

  validates :file_name, presence: true
  validates :prompt_text, presence: true
  validates :source_id, uniqueness: { scope: :inbox_id }, allow_nil: true

  before_validation :normalize_source_id

  scope :for_source, lambda { |account_id:, inbox_id:, source_id:|
    where(account_id: account_id, inbox_id: inbox_id, source_id: source_id)
  }

  def self.prompt_for(account_id:, inbox_id:, source_id: nil)
    prompts = where(account_id: account_id, inbox_id: inbox_id)

    if source_id.present?
      exact_prompt = prompts.find_by(source_id: source_id)
      return exact_prompt if exact_prompt.present?
    end

    [nil, '', *DEFAULT_SOURCE_IDS].each do |default_source_id|
      default_prompt = prompts.find_by(source_id: default_source_id)
      return default_prompt if default_prompt.present?
    end

    nil
  end

  def self.prompt_text_for(account_id:, inbox_id:, source_id: nil)
    prompt_for(account_id: account_id, inbox_id: inbox_id, source_id: source_id)&.prompt_text
  end

  private

  def normalize_source_id
    self.source_id = source_id.to_s.strip.presence
  end
end
