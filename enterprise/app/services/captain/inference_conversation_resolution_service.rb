# frozen_string_literal: true

# Resolves a conversation after Captain infers there are no outstanding questions
# (same side-effects as Captain::InboxPendingConversationsResolutionJob#resolve_conversation).
class Captain::InferenceConversationResolutionService
  pattr_initialize [:conversation!, :inbox!, :evaluation_reason!]

  def perform
    create_private_note
    create_resolution_message

    Current.executed_by ||= inbox.captain_assistant

    conversation.with_captain_activity_context(
      reason: Captain::InboxPendingConversationsResolutionJob::CAPTAIN_INFERENCE_RESOLVE_ACTIVITY_REASON,
      reason_type: :inference
    ) { conversation.resolved! }

    conversation.dispatch_captain_inference_resolved_event
  end

  private

  def create_private_note
    conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: inbox.captain_assistant,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      content: "Auto-resolved: #{evaluation_reason}"
    )
  end

  def create_resolution_message
    I18n.with_locale(inbox.account.locale) do
      resolution_message = inbox.captain_assistant.config['resolution_message']
      conversation.messages.create!(
        message_type: :outgoing,
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        content: resolution_message.presence || I18n.t('conversations.activity.auto_resolution_message'),
        sender: inbox.captain_assistant
      )
    end
  end
end
