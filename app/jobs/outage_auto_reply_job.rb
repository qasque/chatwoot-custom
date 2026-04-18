class OutageAutoReplyJob < ApplicationJob
  queue_as :low

  def perform(message_id, agent_id, content)
    message = Message.find_by(id: message_id)
    return if message.blank? || !message.incoming?

    conversation = message.conversation
    agent = conversation.account.users.find_by(id: agent_id)
    return if agent.blank?

    account_user = agent.account_users.find_by(account_id: conversation.account.id)
    return if account_user.blank?

    assign_current(conversation.account, agent, account_user)
    send_outage_reply(conversation, message, agent, agent_id, content)
  ensure
    Current.reset
  end

  private

  def assign_current(account, agent, account_user)
    Current.account = account
    Current.user = agent
    Current.account_user = account_user
  end

  def send_outage_reply(conversation, trigger_message, agent, agent_id, content)
    conversation.with_lock do
      unless duplicate_outage_reply?(conversation, trigger_message)
        Conversations::AssignmentService.new(conversation: conversation, assignee_id: agent_id).perform
        Messages::MessageBuilder.new(agent, conversation, outage_reply_params(content)).perform
      end
    end
  end

  def outage_reply_params(content)
    ActionController::Parameters.new(
      content: content,
      private: false,
      content_attributes: { outage_auto_reply: true }
    )
  end

  def duplicate_outage_reply?(conversation, trigger)
    conversation.messages
                .outgoing
                .where(private: false)
                .where('messages.id > ?', trigger.id)
                .where("content_attributes->>'outage_auto_reply' = 'true'")
                .exists?
  end
end
