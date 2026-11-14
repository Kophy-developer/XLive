import { listSavedVideos, saveVideo, unsaveVideo } from "./api/misc";

export type SavedMediaRef = {
  targetType: string;
  targetId: string;
  savedAt: string;
  title?: string;
  thumbnailUrl?: string;
  mediaType?: string;
  locked?: boolean;
};

const LOCAL_PREFIX = "xlive_saved_media_v3_";

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
  if (!t || t === "post" || t === "reel" || t === "photo" || t === "image") return "video";
  return t;
}

function uniqueIds(targetIds: string[]) {
  const seen = new Set<string>();
  const ids: string[] = [];
  for (const raw of targetIds) {
    const id = String(raw || "").trim();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    ids.push(id);
  }
  return ids;
}

export function canSaveMediaType(targetType: string) {
  const t = normalizeType(targetType);
  return t !== "clip" && t !== "stream";
}

function preferAlbumText(...values: unknown[]) {
  const texts = values.map((v) => String(v || "").trim()).filter(Boolean);
  const withMarker = texts.find((t) => t.includes("xlive_album:"));
  return withMarker || texts[0] || undefined;
}

function parseRemoteItem(row: Record<string, unknown>): SavedMediaRef | null {
  const targetId = String(row.targetId || row.id || row._id || row.videoId || "").trim();
  if (!targetId) return null;
  const access =
    row.access && typeof row.access === "object" ? (row.access as Record<string, unknown>) : null;
  const locked =
    access?.allowed === false || access?.needsPurchase === true || access?.needsUnlock === true;
  return {
    targetType: normalizeType(String(row.targetType || row.type || "video")),
    targetId,
    savedAt: String(row.savedAt || row.createdAt || new Date().toISOString()),
    title: preferAlbumText(row.caption, row.title, row.description, row.name),
    thumbnailUrl: String(row.thumbnailUrl || row.thumbnail || row.previewUrl || "").trim() || undefined,
    mediaType: String(row.mediaType || "").trim() || undefined,
    locked: Boolean(locked),
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

export function isSavedLocalAll(userId: string, targetIds: string[]) {
  const ids = uniqueIds(targetIds);
  if (!ids.length) return false;
  const items = readLocal(userId);
  return ids.every((id) => items.some((e) => e.targetId === id));
}

export async function toggleSavedMedia(
  userId: string,
  targetType: string,
  targetId: string,
  canView: boolean,
  targetIds?: string[]
) {
  return toggleSavedMediaGroup(userId, targetType, uniqueIds([...(targetIds || []), targetId]), canView);
}

export async function toggleSavedMediaGroup(
  userId: string,
  targetType: string,
  targetIds: string[],
  canView: boolean
) {
  if (!canView || !userId) return false;
  const type = normalizeType(targetType);
  const ids = uniqueIds(targetIds);
  if (!ids.length) return false;
  if (!canSaveMediaType(type)) {
    throw new Error("Only posts and videos can be saved.");
  }

  const previous = readLocal(userId);
  const allSaved = ids.every((id) => previous.some((e) => e.targetId === id));

  if (allSaved) {
    const next = previous.filter((e) => !ids.includes(e.targetId));
    writeLocal(userId, next);
    try {
      await Promise.all(ids.map((id) => unsaveVideo(id)));
    } catch (err) {
      writeLocal(userId, previous);
      try {
        await syncSavedFromApi(userId);
      } catch {
        /* keep rolled-back local */
      }
      throw err;
    }
    return false;
  }

  const missing = ids.filter((id) => !previous.some((e) => e.targetId === id));
  const now = new Date().toISOString();
  const added: SavedMediaRef[] = missing.map((id) => ({
    targetType: type,
    targetId: id,
    savedAt: now,
  }));
  writeLocal(userId, [...added, ...previous].slice(0, 500));
  try {
    await Promise.all(missing.map((id) => saveVideo(id)));
  } catch (err) {
    writeLocal(userId, previous);
    try {
      await syncSavedFromApi(userId);
    } catch {
      /* keep rolled-back local */
    }
    throw err;
  }
  return true;
}

export async function syncSavedFromApi(userId: string): Promise<SavedMediaRef[]> {
  if (!userId) return [];
  const remoteRows = await listSavedVideos(1, 100);
  const remote = remoteRows
    .map((row) => parseRemoteItem(row))
    .filter((e): e is SavedMediaRef => !!e)
    .sort((a, b) => b.savedAt.localeCompare(a.savedAt));
  writeLocal(userId, remote);
  return remote;
}

export async function syncSavedFromSettings(userId: string) {
  return syncSavedFromApi(userId);
}
