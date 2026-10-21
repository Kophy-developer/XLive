import { getSettings, updateSettings } from "./api/misc";

export type SavedMediaRef = {
  targetType: string;
  targetId: string;
  savedAt: string;
};

const LOCAL_PREFIX = "xlive_saved_media_v1_";
const SETTINGS_FIELD = "savedMediaIds";

function localKey(userId: string) {
  return `${LOCAL_PREFIX}${userId}`;
}

function readLocal(userId: string): SavedMediaRef[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(localKey(userId));
    if (!raw) return [];
    const parsed = JSON.parse(raw) as SavedMediaRef[];
    return Array.isArray(parsed) ? parsed.filter((e) => e?.targetId) : [];
  } catch {
    return [];
  }
}

function writeLocal(userId: string, items: SavedMediaRef[]) {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(localKey(userId), JSON.stringify(items.slice(0, 500)));
  } catch {
    return;
  }
}

export function listSavedLocal(userId: string) {
  return readLocal(userId);
}

export function isSavedLocal(userId: string, targetType: string, targetId: string) {
  const key = `${targetType}:${targetId}`;
  return readLocal(userId).some((e) => `${e.targetType}:${e.targetId}` === key);
}

export async function toggleSavedMedia(
  userId: string,
  targetType: string,
  targetId: string,
  canView: boolean
) {
  if (!canView || !userId || !targetId) return false;
  const type = targetType || "video";
  let items = readLocal(userId);
  const key = `${type}:${targetId}`;
  const exists = items.some((e) => `${e.targetType}:${e.targetId}` === key);
  if (exists) {
    items = items.filter((e) => `${e.targetType}:${e.targetId}` !== key);
  } else {
    items = [
      { targetType: type, targetId, savedAt: new Date().toISOString() },
      ...items,
    ].slice(0, 500);
  }
  writeLocal(userId, items);
  try {
    await updateSettings({ [SETTINGS_FIELD]: items });
  } catch {
    /* settings may strip unknown fields; local still works */
  }
  return !exists;
}

export async function syncSavedFromSettings(userId: string) {
  if (!userId) return readLocal(userId);
  try {
    const res = await getSettings();
    const data = (res as { data?: Record<string, unknown> })?.data ?? (res as Record<string, unknown>);
    const raw = data?.[SETTINGS_FIELD];
    if (!Array.isArray(raw)) return readLocal(userId);
    const remote = raw
      .filter((e): e is Record<string, unknown> => !!e && typeof e === "object")
      .map((e) => ({
        targetType: String(e.targetType || e.type || "video"),
        targetId: String(e.targetId || e.id || ""),
        savedAt: String(e.savedAt || e.createdAt || new Date().toISOString()),
      }))
      .filter((e) => e.targetId);
    const map = new Map<string, SavedMediaRef>();
    for (const e of [...readLocal(userId), ...remote]) {
      map.set(`${e.targetType}:${e.targetId}`, e);
    }
    const merged = Array.from(map.values()).sort((a, b) => b.savedAt.localeCompare(a.savedAt));
    writeLocal(userId, merged);
    return merged;
  } catch {
    return readLocal(userId);
  }
}
