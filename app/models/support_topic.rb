# frozen_string_literal: true

class SupportTopic < ApplicationRecord
  belongs_to :account
  has_many :conversations, dependent: :nullify

  before_validation :normalize_name_fields

  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: { scope: :account_id }

  private

  def normalize_name_fields
    self.name = name.to_s.strip
    self.normalized_name = name.to_s.downcase.squish
  end
end
