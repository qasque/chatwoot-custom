FactoryBot.define do
  factory :traffic_source_prompt do
    association :account
    association :inbox, account: account
    sequence(:source_id) { |n| "source-#{n}" }
    file_name { 'prompt.txt' }
    prompt_text { 'Test prompt content' }
  end
end
