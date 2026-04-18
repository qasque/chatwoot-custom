class Api::V1::Accounts::OutageAutoReplyController < Api::V1::Accounts::BaseController
  CONFIG_KEY = 'outage_auto_reply'.freeze

  def show
    render json: response_payload
  end

  def update
    cfg = build_updated_config
    if enabled_without_content?(cfg)
      return render json: {
        error: I18n.t('api.outage_auto_reply.enabled_requires_message_and_inboxes')
      }, status: :unprocessable_entity
    end

    persist_outage_config(cfg)
    render json: response_payload
  end

  private

  def build_updated_config
    permitted = params.require(:outage_auto_reply).permit(:enabled, :message, inbox_ids: [])
    attrs = current_account.custom_attributes || {}
    cfg = (attrs[CONFIG_KEY] || {}).stringify_keys

    apply_outage_permitted!(cfg, permitted)
    cfg
  end

  def apply_outage_permitted!(cfg, permitted)
    if permitted.key?(:enabled)
      cfg['enabled'] = ActiveModel::Type::Boolean.new.cast(permitted[:enabled])
      cfg['agent_id'] = current_user.id if cfg['enabled']
    end
    cfg['message'] = permitted[:message].to_s if permitted.key?(:message)
    return unless permitted.key?(:inbox_ids)

    cfg['inbox_ids'] = permitted[:inbox_ids].to_a.map(&:to_i).uniq
  end

  def enabled_without_content?(cfg)
    cfg['enabled'] && (cfg['message'].to_s.strip.blank? || cfg['inbox_ids'].blank?)
  end

  def persist_outage_config(cfg)
    attrs = current_account.custom_attributes || {}
    attrs = attrs.merge(CONFIG_KEY => cfg)
    current_account.update!(custom_attributes: attrs)
  end

  def response_payload
    cfg = (current_account.custom_attributes || {})[CONFIG_KEY] || {}
    cfg = cfg.stringify_keys
    {
      enabled: cfg['enabled'] == true || cfg['enabled'].to_s == 'true',
      message: cfg['message'].to_s,
      inbox_ids: Array(cfg['inbox_ids']).map(&:to_i),
      agent_id: cfg['agent_id'].to_i
    }
  end
end
