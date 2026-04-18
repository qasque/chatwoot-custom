/** Internal task markers on private notes (Latin + RU UI). */
export const TASK_NOTE_PREFIXES = ['[TASK]', '[ЗАДАЧИ]'];

export function isTaskNoteContent(content) {
  if (!content || typeof content !== 'string') return false;
  const t = content.trim().toUpperCase();
  return TASK_NOTE_PREFIXES.some(p => t.startsWith(p.toUpperCase()));
}

export function isTaskPrivateNoteMessage(message) {
  if (!message || message.private !== true) return false;
  return isTaskNoteContent(message.content);
}

/** Human-readable task title (without prefix). */
export function stripTaskNoteTitle(content) {
  if (!content || typeof content !== 'string') return '';
  const s = content.trim();
  const upper = s.toUpperCase();
  const matched = TASK_NOTE_PREFIXES.find(prefix =>
    upper.startsWith(prefix.toUpperCase())
  );
  if (!matched) return s;
  return s.slice(matched.length).trim();
}

/** Normalized storage format (API / search use [TASK]). */
export function formatTaskNoteMessage(body) {
  const b = (body || '').trim();
  if (!b) return '[TASK] ';
  if (isTaskNoteContent(b)) return b;
  return `[TASK] ${b}`;
}
