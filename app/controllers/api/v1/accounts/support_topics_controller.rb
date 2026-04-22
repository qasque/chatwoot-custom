# frozen_string_literal: true

class Api::V1::Accounts::SupportTopicsController < Api::V1::Accounts::BaseController
  def index
    topics = Current.account.support_topics.order(updated_at: :desc)
    render json: {
      payload: topics.map { |topic| { id: topic.id, name: topic.name } }
    }
  end
end
