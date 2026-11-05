import { listSavedVideos, saveVideo, unsaveVideo } from "./api/misc";

export type SavedMediaRef = {
  targetType: string;
  targetId: string;
  savedAt: string;
};

const LOCAL_PREFIX = "xlive_saved_media_v2_";

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

function normalizeType(targetType: string) {
  const t = (targetType || "video").trim().toLowerCase();
  if (!t || t === "post" || t === "reel" || t === "photo") return "video";
  return t;
}

function parseRemoteItem(row: Record<string, unknown>): SavedMediaRef | null {
  const targetId = String(row.targetId || row.id || row._id || row.videoId || "").trim();
  if (!targetId) return null;
  return {
    targetType: normalizeType(String(row.targetType || row.type || "video")),
    targetId,
    savedAt: String(row.savedAt || row.createdAt || new Date().toISOString()),
  };
}

export function listSavedLocal(userId: string) {
  return readLocal(userId);
}

export function isSavedLocal(userId: string, targetType: string, targetId: string) {
  const id = targetId.trim();
  if (!id) return false;
  return readLocal(userId).some((e) => e.targetId === id);
}

export async function toggleSavedMedia(
  userId: string,
  targetType: string,
  targetId: string,
  canView: boolean
) {
  if (!canView || !userId || !targetId) return false;
  const type = normalizeType(targetType);
  const id = targetId.trim();
  let items = readLocal(userId);
  const exists = items.some((e) => e.targetId === id);
  if (exists) {
    items = items.filter((e) => e.targetId !== id);
    writeLocal(userId, items);
    try {
      await unsaveVideo(id);
    } catch (err) {
      writeLocal(userId, [
        { targetType: type, targetId: id, savedAt: new Date().toISOString() },
        ...items,
      ]);
      throw err;
    }
    return false;
  }
  items = [{ targetType: type, targetId: id, savedAt: new Date().toISOString() }, ...items].slice(0, 500);
  writeLocal(userId, items);
  try {
    await saveVideo(id);
  } catch (err) {
    writeLocal(
      userId,
      items.filter((e) => e.targetId !== id)
    );
    throw err;
  }
  return true;
}

export async function syncSavedFromApi(userId: string): Promise<SavedMediaRef[]> {
  if (!userId) return [];
  const remoteRows = await listSavedVideos(1, 100);
  const remote = remoteRows
    .map((row) => parseRemoteItem(row))
    .filter((e): e is SavedMediaRef => !!e);
  const map = new Map<string, SavedMediaRef>();
  for (const e of remote) map.set(e.targetId, e);
  const merged = Array.from(map.values()).sort((a, b) => b.savedAt.localeCompare(a.savedAt));
  writeLocal(userId, merged);
  return merged;
}

export async function syncSavedFromSettings(userId: string) {
  return syncSavedFromApi(userId);
}
