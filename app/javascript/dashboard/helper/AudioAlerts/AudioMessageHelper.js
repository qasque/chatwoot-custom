export const getAssignee = message => message?.conversation?.assignee_id;
export const isConversationUnassigned = message => !getAssignee(message);
export const isConversationAssignedToMe = (message, currentUserId) =>
  getAssignee(message) === currentUserId;
export const isMessageFromCurrentUser = (message, currentUserId) =>
  message?.sender?.id === currentUserId;

export const AI_HANDOFF_CUSTOM_ATTR = 'ai_handoff';

/** Синхронно с ai-bot: PATCH custom_attributes.ai_handoff при переводе на оператора. */
export const isAiHandoffToOperatorActive = conversation => {
  if (!conversation) return false;
  const custom = conversation.custom_attributes;
  if (!custom || typeof custom !== 'object') return false;
  const val = custom[AI_HANDOFF_CUSTOM_ATTR];
  if (val === true) return true;
  if (typeof val === 'string') {
    const s = val.trim().toLowerCase();
    if (s === 'true' || s === '1' || s === 'yes') return true;
  }
  return false;
};
