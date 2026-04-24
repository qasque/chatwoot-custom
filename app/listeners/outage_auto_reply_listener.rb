class OutageAutoReplyListener < BaseListener
  CONFIG_KEY = 'outage_auto_reply'.freeze

  def message_created(event)
    message = event.data[:message]
    return if skip_outage_processing?(message, event)

    account = message.account
    cfg = outage_config(account)
    return unless outage_mode_enabled?(cfg)
    return unless inbox_allowed?(message, cfg)

    content = cfg['message'].to_s.strip
    return if content.blank?

    agent_id = cfg['agent_id'].to_i
    return if agent_id.zero?
    # Каждое новое входящее в выбранных инбоксах; дубликат на одно событие отсекает
    # OutageAutoReplyJob#duplicate_outage_reply?
    OutageAutoReplyJob.perform_later(message.id, agent_id, content)
  end

  private

  def skip_outage_processing?(message, event)
    !message&.incoming? ||
      message.private? ||
      message.activity? ||
      message.auto_reply_email? ||
      performed_by_automation?(event) ||
      outage_auto_reply_message?(message)
  end

  def performed_by_automation?(event)
    performed = event.data[:performed_by]
    performed.present? && performed.instance_of?(AutomationRule)
  end

  def outage_auto_reply_message?(message)
    message.content_attributes['outage_auto_reply'] == true
  end

  def outage_config(account)
    (account.custom_attributes || {})[CONFIG_KEY] || {}
  end

  def outage_mode_enabled?(cfg)
    cfg['enabled'] == true || cfg['enabled'].to_s == 'true'
  end

  def inbox_allowed?(message, cfg)
    inbox_ids = Array(cfg['inbox_ids']).map(&:to_i).reject(&:zero?)
    inbox_ids.empty? || inbox_ids.include?(message.inbox_id)
  end

end
