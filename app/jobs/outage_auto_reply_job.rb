class OutageAutoReplyJob < ApplicationJob
  queue_as :low

  def perform(message_id, agent_id, content)
    message = Message.find_by(id: message_id)
    return if message.blank?
    return unless message.incoming?

    conversation = message.conversation
    account = conversation.account
    agent = account.users.find_by(id: agent_id)
    return if agent.blank?

    account_user = agent.account_users.find_by(account_id: account.id)
    return if account_user.blank?

    Current.account = account
    Current.user = agent
    Current.account_user = account_user

    conversation.with_lock do
      return if duplicate_outage_reply?(conversation, message)

      Conversations::AssignmentService.new(conversation: conversation, assignee_id: agent_id).perform

      params = ActionController::Parameters.new(
        content: content,
        private: false,
        content_attributes: { outage_auto_reply: true }
      )
      Messages::MessageBuilder.new(agent, conversation, params).perform
    end
  ensure
    Current.reset
  end

  private

  def duplicate_outage_reply?(conversation, trigger)
    conversation.messages
                .outgoing
                .where(private: false)
                .where('messages.id > ?', trigger.id)
                .where("content_attributes->>'outage_auto_reply' = 'true'")
                .exists?
  end
end
