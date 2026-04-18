class OutageBroadcastJob < ApplicationJob
  queue_as :low

  def perform(account_id, inbox_ids, content, user_id)
    account = Account.find(account_id)
    user = User.find(user_id)
    account_user = user.account_users.find_by(account_id: account.id)
    return if account_user.blank?

    setup_current(account, user, account_user)
    deliver_broadcast(account, user, inbox_ids, content)
  ensure
    Current.reset
  end

  private

  def setup_current(account, user, account_user)
    Current.account = account
    Current.user = user
    Current.account_user = account_user
  end

  def deliver_broadcast(account, user, inbox_ids, content)
    valid_inbox_ids = account.inboxes.where(id: inbox_ids).pluck(:id)
    return if valid_inbox_ids.blank?

    broadcast_params = ActionController::Parameters.new(content: content, private: false)
    scope = account.conversations.where(inbox_id: valid_inbox_ids).where.not(status: :resolved)

    scope.find_each(batch_size: 100) do |conversation|
      Messages::MessageBuilder.new(user, conversation, broadcast_params).perform
    rescue StandardError => e
      Rails.logger.error "[OutageBroadcast] conversation #{conversation.id}: #{e.message}"
    end
  end
end
