# frozen_string_literal: true

class Support::DailyTelegramReportBuilder
  BAR_WIDTH = 20
  AI_SENDERS = %w[AgentBot Captain::Assistant].freeze

  def initialize(account:, period_start:, period_end:)
    @account = account
    @period_start = period_start
    @period_end = period_end
  end

  def perform
    blocks = inboxes.map { |inbox| build_inbox_block(inbox) }
    totals = build_totals(blocks)

    ([header] + blocks.map { |b| b[:text] } + [totals_block(totals)]).join("\n\n")
  end

  private

  attr_reader :account, :period_start, :period_end

  def inboxes
    @inboxes ||= account.inboxes.order(:name)
  end

  def header
    "<b>📊 Техподдержка | #{fmt_time(period_start)} → #{fmt_time(period_end)} (МСК)</b>"
  end

  def build_inbox_block(inbox)
    conversations = account.conversations.where(inbox_id: inbox.id, created_at: period_start...period_end)
    conversation_ids = conversations.pluck(:id)
    metrics = compute_metrics(inbox, conversations, conversation_ids)

    {
      metrics: metrics,
      text: [
        separator,
        "<b>🔹 Сервис: #{h(inbox.name)}</b>",
        separator,
        '',
        '<b>Воронка:</b>',
        funnel_lines(metrics),
        '',
        '<b>Топ-5 тем обращений:</b>',
        topics_lines(metrics[:topics]),
        '',
        "Среднее время первого ответа: #{duration(metrics[:avg_first_response])}",
        "Среднее время решения: #{duration(metrics[:avg_resolution_time])}"
      ].join("\n")
    }
  end

  def compute_metrics(inbox, conversations, conversation_ids)
    return empty_metrics if conversation_ids.empty?

    message_scope = Message.where(conversation_id: conversation_ids, private: false, message_type: Message.message_types[:outgoing])
    ai_conversation_ids = message_scope.where(sender_type: AI_SENDERS).distinct.pluck(:conversation_id)
    operator_conversation_ids = message_scope.where(sender_type: 'User').distinct.pluck(:conversation_id)

    handoff_ids = ReportingEvent.where(
      account_id: account.id,
      inbox_id: inbox.id,
      name: 'conversation_bot_handoff',
      created_at: period_start...period_end
    ).distinct.pluck(:conversation_id)

    operator_after_ai_ids = operator_conversation_ids & ai_conversation_ids
    escalated_ids = (handoff_ids + operator_after_ai_ids).uniq

    {
      total: conversations.count,
      ai_accepted: ai_conversation_ids.size,
      ai_resolved: ai_resolved_count(inbox, conversation_ids),
      escalated: escalated_ids.size,
      operator_resolved: operator_resolved_count(inbox, conversation_ids),
      unresolved: conversations.where.not(status: :resolved).count,
      topics: top_topics(conversations),
      avg_first_response: avg_event_value(inbox.id, 'first_response'),
      avg_resolution_time: avg_event_value(inbox.id, 'conversation_resolved')
    }
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
    names = conversations.pluck(:custom_attributes, :cached_label_list).map do |custom_attributes, cached_labels|
      topic_from(custom_attributes, cached_labels)
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

  def funnel_lines(metrics)
    stages = [
      ['Поступило', metrics[:total]],
      ['AI принял', metrics[:ai_accepted]],
      ['AI решил', metrics[:ai_resolved]],
      ['Эскалация', metrics[:escalated]],
      ['Оператор решил', metrics[:operator_resolved]],
      ['Не решено', metrics[:unresolved]]
    ]

    stages.each_with_index.map do |(label, count), idx|
      line = format('%-16s %s %4d (%s)', label, bar(count, metrics[:total]), count, pct(count, metrics[:total]))
      if idx.positive?
        line += "  #{dropoff(stages[idx - 1][1], count)}"
      end
      line
    end.join("\n")
  end

  def topics_lines(topics)
    return '  — Нет данных' if topics.blank?

    total = topics.sum { |_name, count| count }
    topics.each_with_index.map do |(name, count), idx|
      " #{idx + 1}. #{h(name)} — #{count} (#{pct(count, total)})"
    end.join("\n")
  end

  def build_totals(blocks)
    metrics = blocks.map { |b| b[:metrics] }
    total = metrics.sum { |m| m[:total] }
    ai_resolved = metrics.sum { |m| m[:ai_resolved] }
    escalated = metrics.sum { |m| m[:escalated] }
    unresolved = metrics.sum { |m| m[:unresolved] }

    {
      total: total,
      ai_resolution_rate: pct(ai_resolved, total),
      escalation_rate: pct(escalated, total),
      unresolved_rate: pct(unresolved, total)
    }
  end

  def totals_block(totals)
    [
      separator,
      '<b>📈 Итого по всем сервисам</b>',
      separator,
      "Всего обращений: #{totals[:total]}",
      "AI resolution rate: #{totals[:ai_resolution_rate]}",
      "Эскалаций: #{totals[:escalation_rate]}",
      "Не решено: #{totals[:unresolved_rate]}"
    ].join("\n")
  end

  def bar(value, total)
    ratio = total.positive? ? value.to_f / total : 0
    filled = (BAR_WIDTH * ratio).round
    '█' * filled + '░' * (BAR_WIDTH - filled)
  end

  def pct(value, total)
    return '0%' if total.to_i.zero?

    "#{((value.to_f / total) * 100).round}%"
  end

  def dropoff(prev_value, current_value)
    return '↓ 0%' if prev_value.to_i.zero?

    change = ((current_value.to_f - prev_value) / prev_value * 100).round
    sign = change.positive? ? '+' : ''
    arrow = change.positive? ? '↑' : '↓'
    "#{arrow} #{sign}#{change}%"
  end

  def duration(seconds)
    return '—' if seconds.to_f <= 0

    total = seconds.to_i
    mins = total / 60
    secs = total % 60
    "#{mins}м #{secs}с"
  end

  def fmt_time(time)
    time.in_time_zone('Europe/Moscow').strftime('%d.%m %H:%M')
  end

  def separator
    '━━━━━━━━━━━━━━━━━━━━━━━━'
  end

  def h(text)
    CGI.escapeHTML(text.to_s)
  end

  def empty_metrics
    {
      total: 0,
      ai_accepted: 0,
      ai_resolved: 0,
      escalated: 0,
      operator_resolved: 0,
      unresolved: 0,
      topics: [],
      avg_first_response: 0,
      avg_resolution_time: 0
    }
  end
end
