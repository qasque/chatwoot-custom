# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupportTopic do
  describe 'validations' do
    it 'normalizes name and enforces uniqueness by normalized name inside account' do
      account = create(:account)
      create(:support_topic, account: account, name: '  Не работает VPN  ')

      duplicate = build(:support_topic, account: account, name: 'не   работает vpn')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:normalized_name]).to be_present
    end
  end
end
