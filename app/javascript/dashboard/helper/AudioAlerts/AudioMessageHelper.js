export const getAssignee = message => message?.conversation?.assignee_id;
export const isConversationUnassigned = message => !getAssignee(message);
export const isConversationAssignedToMe = (message, currentUserId) =>
  getAssignee(message) === currentUserId;
export const isMessageFromCurrentUser = (message, currentUserId) =>
  message?.sender?.id === currentUserId;

export const AI_HANDOFF_CUSTOM_ATTR = 'ai_handoff';

/** True when ai-bot set custom_attributes.ai_handoff (human takeover). */
export const isAiHandoffToOperatorActive = conversation => {
  if (!conversation) return false;
  const custom = conversation.custom_attributes;
  if (!custom || typeof custom !== 'object') return false;
  const val = custom[AI_HANDOFF_CUSTOM_ATTR];
  if (val === true || val === 1) return true;
  if (typeof val === 'string') {
    const s = val.trim().toLowerCase();
    if (s === 'true' || s === '1' || s === 'yes') return true;
  }
  return false;
};

/**
 * Restrict audio until ai_handoff only when vueapp injected `disableAiHandoffAudioGate`.
 * Empty `window.chatwootConfig` from other tests must not enable the gate.
 */
export const isAiHandoffAudioGateActive = () => {
  if (typeof window === 'undefined') return false;
  const cfg = window.chatwootConfig;
  if (cfg == null || typeof cfg !== 'object') return false;
  if (!Object.prototype.hasOwnProperty.call(cfg, 'disableAiHandoffAudioGate')) {
    return false;
  }
  return !cfg.disableAiHandoffAudioGate;
};
