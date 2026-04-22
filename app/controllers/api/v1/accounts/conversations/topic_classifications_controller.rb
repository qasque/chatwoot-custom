# frozen_string_literal: true

class Api::V1::Accounts::Conversations::TopicClassificationsController < Api::V1::Accounts::Conversations::BaseController
  def show
    render json: {
      conversation_id: @conversation.display_id,
      support_topic: serialize_topic(@conversation.support_topic),
      incoming_public_messages_count: incoming_public_messages_count,
      topics: topics_scope.map { |topic| serialize_topic(topic) }
    }
  end

  def create
    topic = resolve_topic_from_params
    return render json: { error: 'existing_topic_id or topic_name is required' }, status: :unprocessable_entity if topic.blank?

    @conversation.update!(support_topic: topic)

    render json: {
      conversation_id: @conversation.display_id,
      support_topic: serialize_topic(topic)
    }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def topics_scope
    Current.account.support_topics.order(updated_at: :desc)
  end

  def incoming_public_messages_count
    @conversation.messages.where(
      private: false,
      message_type: Message.message_types[:incoming]
    ).count
  end

  def resolve_topic_from_params
    existing_topic_id = params[:existing_topic_id].presence
    return Current.account.support_topics.find_by(id: existing_topic_id) if existing_topic_id

    raw_name = params[:topic_name].presence || params[:new_topic_name].presence
    return nil if raw_name.blank?

    normalized = raw_name.to_s.downcase.squish
    topic = Current.account.support_topics.find_or_initialize_by(normalized_name: normalized)
    topic.name = raw_name.to_s.strip
    topic.save! if topic.new_record? || topic.name != raw_name.to_s.strip
    topic
  end

  def serialize_topic(topic)
    return nil if topic.blank?

    {
      id: topic.id,
      name: topic.name
    }
  end
end
