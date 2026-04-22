# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Support::DailyTelegramReportBuilder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, name: 'Support') }
  let(:period_end) { Time.zone.parse('2026-04-15 09:00:00') }
  let(:period_start) { period_end - 24.hours }

  describe '#perform' do
    it 'renders header and totals when there are no conversations' do
      inbox # ensure inbox exists for account

      text = described_class.new(
        account: account,
        period_start: period_start,
        period_end: period_end
      ).perform

      expect(text).to include('Техподдержка')
      expect(text).to include('Europe/Moscow')
      expect(text).to include('Итого по всем сервисам')
      expect(text).to include('Всего обращений: 0')
    end

    it 'limits blocks to selected inbox ids' do
      create(:inbox, account: account, name: 'A')
      inbox_b = create(:inbox, account: account, name: 'B')

      text = described_class.new(
        account: account,
        period_start: period_start,
        period_end: period_end,
        inbox_ids: [inbox_b.id]
      ).perform

      expect(text).to include('Сервис: B')
      expect(text).not_to include('Сервис: A')
    end

    it 'includes topic from custom_attributes in top topics' do
      create(
        :conversation,
        account: account,
        inbox: inbox,
        created_at: period_start + 1.hour,
        custom_attributes: { 'topic' => 'Оплата' }
      )

      text = described_class.new(
        account: account,
        period_start: period_start,
        period_end: period_end
      ).perform

      expect(text).to include('Оплата')
    end

    it 'prefers support topic name and keeps fallback for uncategorized conversations' do
      support_topic = create(:support_topic, account: account, name: 'Не подключается VPN')
      create(
        :conversation,
        account: account,
        inbox: inbox,
        created_at: period_start + 1.hour,
        support_topic: support_topic
      )
      create(
        :conversation,
        account: account,
        inbox: inbox,
        created_at: period_start + 2.hours,
        custom_attributes: { 'topic' => 'Оплата' }
      )

      text = described_class.new(
        account: account,
        period_start: period_start,
        period_end: period_end
      ).perform

      expect(text).to include('Не подключается VPN')
      expect(text).to include('Оплата')
    end

    it 'counts operator_resolved from reporting events excluding bot-only resolutions' do
      user = create(:user, account: account)
      conv_bot = create(:conversation, account: account, inbox: inbox, created_at: period_start + 30.minutes)
      conv_human = create(:conversation, account: account, inbox: inbox, created_at: period_start + 45.minutes)

      create(
        :reporting_event,
        account: account,
        inbox: inbox,
        conversation: conv_bot,
        user: user,
        name: 'conversation_resolved',
        created_at: period_start + 2.hours,
        value: 120
      )
      create(
        :reporting_event,
        account: account,
        inbox: inbox,
        conversation: conv_bot,
        user: user,
        name: 'conversation_bot_resolved',
        created_at: period_start + 2.hours,
        value: 120
      )

      create(
        :reporting_event,
        account: account,
        inbox: inbox,
        conversation: conv_human,
        user: user,
        name: 'conversation_resolved',
        created_at: period_start + 3.hours,
        value: 60
      )

      text = described_class.new(
        account: account,
        period_start: period_start,
        period_end: period_end
      ).perform

      expect(text).to match(/Оператор решил.*\b1\b/)
    end

    it 'counts escalation when operator replies after AI' do
      agent_bot = create(:agent_bot, account: account)
      user = create(:user, account: account)
      conv = create(:conversation, account: account, inbox: inbox, created_at: period_start + 10.minutes)

      create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conv,
        message_type: 'outgoing',
        sender: agent_bot,
        created_at: period_start + 15.minutes
      )
      create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conv,
        message_type: 'outgoing',
        sender: user,
        created_at: period_start + 20.minutes
      )

      text = described_class.new(
        account: account,
        period_start: period_start,
        period_end: period_end
      ).perform

      expect(text).to match(/Эскалация.*\b1\b/)
    end

    it 'counts conversations where the last message is from the bot and the contact did not reply after' do
      agent_bot = create(:agent_bot, account: account)
      contact = create(:contact, account: account)
      conv = create(:conversation, account: account, inbox: inbox, contact: contact, created_at: period_start + 5.minutes)

      create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conv,
        message_type: 'outgoing',
        sender: agent_bot,
        created_at: period_start + 6.minutes
      )

      text = described_class.new(
        account: account,
        period_start: period_start,
        period_end: period_end
      ).perform

      expect(text).to match(/Без ответа после AI.*\b1\b/)
    end

    it 'does not count when the contact replies after the assistant message' do
      agent_bot = create(:agent_bot, account: account)
      contact = create(:contact, account: account)
      conv = create(:conversation, account: account, inbox: inbox, contact: contact, created_at: period_start + 5.minutes)

      create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conv,
        message_type: 'outgoing',
        sender: agent_bot,
        created_at: period_start + 6.minutes
      )
      create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conv,
        message_type: 'incoming',
        sender: contact,
        created_at: period_start + 7.minutes
      )

      text = described_class.new(
        account: account,
        period_start: period_start,
        period_end: period_end
      ).perform

      expect(text).to match(/Без ответа после AI.*\b0\b/)
    end

    it 'does not count pure human threads without AI as escalation' do
      user = create(:user, account: account)
      conv = create(:conversation, account: account, inbox: inbox, created_at: period_start + 5.minutes)

      create(
        :message,
        account: account,
        inbox: inbox,
        conversation: conv,
        message_type: 'outgoing',
        sender: user,
        created_at: period_start + 6.minutes
      )

      text = described_class.new(
        account: account,
        period_start: period_start,
        period_end: period_end
      ).perform

      expect(text).to match(/Эскалация.*\b0\b/)
    end
  end
end
