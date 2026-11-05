const PREFIX = "xlive_unlocked_media_v1_";

function key(userId: string) {
  return `${PREFIX}${userId}`;
}

function read(userId: string): Set<string> {
  if (typeof window === "undefined" || !userId) return new Set();
  try {
    const raw = localStorage.getItem(key(userId));
    if (!raw) return new Set();
    const parsed = JSON.parse(raw) as string[];
    return new Set(Array.isArray(parsed) ? parsed.filter(Boolean) : []);
  } catch {
    return new Set();
  }
}

function write(userId: string, ids: Set<string>) {
  if (typeof window === "undefined" || !userId) return;
  try {
    localStorage.setItem(key(userId), JSON.stringify(Array.from(ids).slice(0, 500)));
  } catch {
    return;
  }
}

export function isUnlockedLocal(userId: string | undefined | null, targetId: string) {
  if (!userId || !targetId) return false;
  return read(userId).has(targetId);
}

export function markUnlockedLocal(userId: string | undefined | null, targetId: string) {
  if (!userId || !targetId) return;
  const ids = read(userId);
  ids.add(targetId);
  write(userId, ids);
}

export function clearUnlockedLocal(userId: string | undefined | null, targetId: string) {
  if (!userId || !targetId) return;
  const ids = read(userId);
  ids.delete(targetId);
  write(userId, ids);
}
