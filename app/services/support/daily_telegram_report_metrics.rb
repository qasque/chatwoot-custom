# frozen_string_literal: true

class Support::DailyTelegramReportMetrics
  AI_SENDERS = %w[AgentBot Captain::Assistant].freeze

  def initialize(account:, period_start:, period_end:)
    @account = account
    @period_start = period_start
    @period_end = period_end
  end

  def for_inbox(inbox, conversations, conversation_ids)
    return empty_metrics if conversation_ids.empty?

    ai_ids, operator_ids = outgoing_conversation_ids_split(conversation_ids)
    handoff_ids = handoff_conversation_ids(inbox)
    escalated_ids = (handoff_ids + (operator_ids & ai_ids)).uniq

    {
      total: conversations.count,
      ai_accepted: ai_ids.size,
      ai_resolved: ai_resolved_count(inbox, conversation_ids),
      no_reply_after_assistant: no_contact_reply_after_assistant_count(conversation_ids),
      escalated: escalated_ids.size,
      operator_resolved: operator_resolved_count(inbox, conversation_ids),
      unresolved: conversations.where.not(status: :resolved).count,
      topics: top_topics(conversations),
      avg_first_response: avg_event_value(inbox.id, 'first_response'),
      avg_resolution_time: avg_event_value(inbox.id, 'conversation_resolved')
    }
  end

  private

  attr_reader :account, :period_start, :period_end

  def outgoing_conversation_ids_split(conversation_ids)
    # Message has `default_scope { order(created_at: :asc) }`; combined with AR internals
    # that can emit DISTINCT, PostgreSQL errors. Use unscoped + explicit reorder(nil).
    base = Message.unscoped.where(
      conversation_id: conversation_ids,
      private: false,
      message_type: Message.message_types[:outgoing]
    )
    ai = base.where(sender_type: AI_SENDERS).reorder(nil).pluck(:conversation_id).uniq
    operators = base.where(sender_type: 'User').reorder(nil).pluck(:conversation_id).uniq
    [ai, operators]
  end

  # Last public message is from AI assistant/bot and contact has not sent incoming after it.
  def no_contact_reply_after_assistant_count(conversation_ids)
    ids = Array(conversation_ids).map(&:to_i).uniq
    return 0 if ids.empty?

    placeholders = (['?'] * ids.size).join(',')
    outgoing = Message.message_types[:outgoing]
    sql = <<~SQL.squish
      SELECT COUNT(*) FROM (
        SELECT m.conversation_id
        FROM messages m
        INNER JOIN (
          SELECT conversation_id, MAX(created_at) AS last_at
          FROM messages
          WHERE private = FALSE AND conversation_id IN (#{placeholders})
          GROUP BY conversation_id
        ) t ON t.conversation_id = m.conversation_id AND t.last_at = m.created_at
        WHERE m.private = FALSE
          AND m.message_type = ?
          AND m.sender_type IN ('AgentBot', 'Captain::Assistant')
          AND m.conversation_id IN (#{placeholders})
      ) x
    SQL
    binds = [*ids, outgoing, *ids]
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql_array([sql, *binds])
    ).to_i
  end

  def handoff_conversation_ids(inbox)
    ReportingEvent.where(
      account_id: account.id,
      inbox_id: inbox.id,
      name: 'conversation_bot_handoff',
      created_at: period_start...period_end
    ).distinct.pluck(:conversation_id)
  end

  def ai_resolved_count(inbox, conversation_ids)
    ReportingEvent.where(
      account_id: account.id,
      inbox_id: inbox.id,
      name: 'conversation_bot_resolved',
      created_at: period_start...period_end,
      conversation_id: conversation_ids
    ).distinct.count(:conversation_id)
  end

  def operator_resolved_count(inbox, conversation_ids)
    bot_resolved_ids = ReportingEvent.where(
      account_id: account.id,
      inbox_id: inbox.id,
      name: 'conversation_bot_resolved',
      created_at: period_start...period_end,
      conversation_id: conversation_ids
    ).distinct.pluck(:conversation_id)

    scope = ReportingEvent.where(
      account_id: account.id,
      inbox_id: inbox.id,
      name: 'conversation_resolved',
      created_at: period_start...period_end,
      conversation_id: conversation_ids
    )
    scope = scope.where.not(conversation_id: bot_resolved_ids) if bot_resolved_ids.present?
    scope.distinct.count(:conversation_id)
  end

  def avg_event_value(inbox_id, event_name)
    ReportingEvent.where(
      account_id: account.id,
      inbox_id: inbox_id,
      name: event_name,
      created_at: period_start...period_end
    ).average(:value).to_f
  end

  def top_topics(conversations)
    names = conversations.left_outer_joins(:support_topic).pluck(
      'support_topics.name',
      :custom_attributes,
      :cached_label_list
    ).map do |topic_name, custom_attributes, cached_labels|
      topic_name.presence || topic_from(custom_attributes, cached_labels)
    end

    names.tally.sort_by { |_k, v| -v }.first(5)
  end

  def topic_from(custom_attributes, cached_labels)
    attrs = custom_attributes || {}
    topic = attrs['topic'].presence || attrs['category'].presence
    return topic if topic.present?

    first_label = cached_labels.to_s.split(',').map(&:strip).reject(&:blank?).first
    first_label.presence || 'Без категории'
  end

  def empty_metrics
    {
      total: 0,
      ai_accepted: 0,
      ai_resolved: 0,
      no_reply_after_assistant: 0,
      escalated: 0,
      operator_resolved: 0,
      unresolved: 0,
      topics: [],
      avg_first_response: 0,
      avg_resolution_time: 0
    }
  end
end
