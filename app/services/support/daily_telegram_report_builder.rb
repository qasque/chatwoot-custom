# frozen_string_literal: true

class Support::DailyTelegramReportBuilder
  BAR_WIDTH = 20

  def initialize(account:, period_start:, period_end:, inbox_ids: nil, display_timezone: 'Europe/Moscow')
    @account = account
    @period_start = period_start
    @period_end = period_end
    @inbox_ids = inbox_ids
    @display_timezone = display_timezone
  end

  def perform
    blocks = inboxes.map { |inbox| build_inbox_block(inbox) }
    totals = build_totals(blocks)

    ([header] + blocks.pluck(:text) + [totals_block(totals)]).join("\n\n")
  end

  private

  attr_reader :account, :period_start, :period_end

  def inboxes
    @inboxes ||= begin
      scope = account.inboxes.order(:name)
      scope = scope.where(id: @inbox_ids) if @inbox_ids.present?
      scope
    end
  end

  def header
    tz = h(@display_timezone.to_s)
    "<b>\u{1F4CA} Техподдержка | #{fmt_time(period_start)} → #{fmt_time(period_end)} (#{tz})</b>"
  end

  def build_inbox_block(inbox)
    conversations = account.conversations.where(inbox_id: inbox.id, created_at: period_start...period_end)
    conversation_ids = conversations.pluck(:id)
    metrics = metrics_calculator.for_inbox(inbox, conversations, conversation_ids)

    { metrics: metrics, text: inbox_block_text(inbox, metrics) }
  end

  def inbox_block_text(inbox, metrics)
    [
      separator,
      "<b>\u{1F539} Сервис: #{h(inbox.name)}</b>",
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
  end

  def metrics_calculator
    @metrics_calculator ||= Support::DailyTelegramReportMetrics.new(
      account: account,
      period_start: period_start,
      period_end: period_end
    )
  end

  def funnel_lines(metrics)
    stages = [
      ['Поступило', metrics[:total]],
      ['AI принял', metrics[:ai_accepted]],
      ['AI решил', metrics[:ai_resolved]],
      ['Без ответа после AI', metrics[:no_reply_after_assistant]],
      ['Эскалация', metrics[:escalated]],
      ['Оператор решил', metrics[:operator_resolved]],
      ['Не решено', metrics[:unresolved]]
    ]

    stages.each_with_index.map do |(label, count), idx|
      line = format(
        '%<label>-22s%<bar>s %<count>4d (%<pct>s)',
        label: label,
        bar: bar(count, metrics[:total]),
        count: count,
        pct: pct(count, metrics[:total])
      )
      line += "  #{dropoff(stages[idx - 1][1], count)}" if idx.positive?
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
    metrics = blocks.pluck(:metrics)
    total = metrics.sum { |m| m[:total] }
    ai_resolved = metrics.sum { |m| m[:ai_resolved] }
    no_reply = metrics.sum { |m| m[:no_reply_after_assistant].to_i }
    escalated = metrics.sum { |m| m[:escalated] }
    unresolved = metrics.sum { |m| m[:unresolved] }

    {
      total: total,
      ai_resolution_rate: pct(ai_resolved, total),
      no_reply_after_assistant_rate: pct(no_reply, total),
      escalation_rate: pct(escalated, total),
      unresolved_rate: pct(unresolved, total)
    }
  end

  def totals_block(totals)
    [
      separator,
      "<b>\u{1F4C8} Итого по всем сервисам</b>",
      separator,
      "Всего обращений: #{totals[:total]}",
      "AI resolution rate: #{totals[:ai_resolution_rate]}",
      "Без ответа клиента после ассистента: #{totals[:no_reply_after_assistant_rate]}",
      "Эскалаций: #{totals[:escalation_rate]}",
      "Не решено: #{totals[:unresolved_rate]}"
    ].join("\n")
  end

  def bar(value, total)
    ratio = total.positive? ? value.to_f / total : 0
    filled = (BAR_WIDTH * ratio).round
    ('█' * filled) + ('░' * (BAR_WIDTH - filled))
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
    time.in_time_zone(@display_timezone).strftime('%d.%m %H:%M')
  end

  def separator
    '━━━━━━━━━━━━━━━━━━━━━━━━'
  end

  def h(text)
    CGI.escapeHTML(text.to_s)
  end
end
