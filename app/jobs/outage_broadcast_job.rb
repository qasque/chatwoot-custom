class OutageBroadcastJob < ApplicationJob
  queue_as :low

  def perform(account_id, inbox_ids, content, user_id)
    account = Account.find(account_id)
    user = User.find(user_id)
    account_user = user.account_users.find_by(account_id: account.id)
    return if account_user.blank?

    Current.account = account
    Current.user = user
    Current.account_user = account_user

    valid_inbox_ids = account.inboxes.where(id: inbox_ids).pluck(:id)
    return if valid_inbox_ids.blank?

    scope = account.conversations.where(inbox_id: valid_inbox_ids).where.not(status: :resolved)
    params = ActionController::Parameters.new(content: content, private: false)

    scope.find_each(batch_size: 100) do |conversation|
      Messages::MessageBuilder.new(user, conversation, params).perform
    rescue StandardError => e
      Rails.logger.error "[OutageBroadcast] conversation #{conversation.id}: #{e.message}"
    end
  ensure
    Current.reset
  end
end
