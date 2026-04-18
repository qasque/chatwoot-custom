class Api::V1::Accounts::OutageBroadcastController < Api::V1::Accounts::BaseController
  def create
    inbox_ids = outage_broadcast_params[:inbox_ids].to_a.map(&:to_i).uniq
    content = outage_broadcast_params[:content].to_s.strip

    return render json: { error: 'inbox_ids and content are required' }, status: :unprocessable_entity if inbox_ids.blank? || content.blank?

    OutageBroadcastJob.perform_later(Current.account.id, inbox_ids, content, Current.user.id)

    render json: {
      success: true,
      message: I18n.t('api.outage_broadcast.enqueued')
    }, status: :accepted
  end

  private

  def outage_broadcast_params
    params.require(:outage_broadcast).permit(:content, inbox_ids: [])
  end
end
