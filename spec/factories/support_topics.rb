# frozen_string_literal: true

FactoryBot.define do
  factory :support_topic do
    account
    sequence(:name) { |n| "Тема #{n}" }
  end
end
