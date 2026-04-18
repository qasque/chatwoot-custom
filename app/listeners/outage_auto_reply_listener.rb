class OutageAutoReplyListener < BaseListener
  CONFIG_KEY = 'outage_auto_reply'.freeze

  def message_created(event)
    message = event.data[:message]
    return unless message&.incoming?
    return if message.private?
    return if message.activity?
    return if message.auto_reply_email?
    return if performed_by_automation?(event)
    return if outage_auto_reply_message?(message)

    account = message.account
    cfg = outage_config(account)
    return unless cfg['enabled'] == true || cfg['enabled'].to_s == 'true'

    inbox_ids = Array(cfg['inbox_ids']).map(&:to_i).reject(&:zero?)
    if inbox_ids.any? && inbox_ids.exclude?(message.inbox_id)
      return
    end

    content = cfg['message'].to_s.strip
    return if content.blank?

    agent_id = cfg['agent_id'].to_i
    return if agent_id.zero?

    return unless eligible_customer_turn?(message)

    OutageAutoReplyJob.perform_later(message.id, agent_id, content)
  end

  private

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

  def eligible_customer_turn?(message)
    conv = message.conversation
    first_incoming = !conv.messages.incoming.where(private: false).where('messages.id < ?', message.id).exists?
    return true if first_incoming

    attrs = message.additional_attributes || {}
    attrs[Message::REOPENED_FROM_RESOLVED_KEY] == true ||
      attrs[Message::REOPENED_FROM_RESOLVED_KEY].to_s == 'true'
  end
end
