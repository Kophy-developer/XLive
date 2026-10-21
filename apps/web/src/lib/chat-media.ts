import type { ChatMessage } from "./types";

const ALBUM_PREFIX = "\u2063xlive_chat_album:";
const ALBUM_SUFFIX = "\u2063";
const NAME_KEY = "xlive_chat_file_names";

export type PendingChatFile = {
  key: string;
  file: File;
  mediaType: "image" | "video" | "document" | "voice";
  caption: string;
  previewUrl?: string;
};

export type ChatBubble =
  | { kind: "single"; message: ChatMessage }
  | { kind: "album"; messages: ChatMessage[] };

export type ChatUploadProgress = {
  index: number;
  total: number;
  name: string;
  pct: number;
};

function loadNames(): Record<string, string> {
  if (typeof window === "undefined") return {};
  try {
    const raw = localStorage.getItem(NAME_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as Record<string, string>;
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function saveNames(map: Record<string, string>) {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(NAME_KEY, JSON.stringify(map));
  } catch {
    return;
  }
}

function persistName(key: string, name: string) {
  if (!key || !name) return;
  const map = loadNames();
  map[key] = name;
  saveNames(map);
}

function lookupName(...keys: Array<string | undefined>) {
  const map = loadNames();
  for (const key of keys) {
    if (key && map[key]) return map[key];
  }
  return "";
}

export function newChatAlbumId() {
  const rand = Math.floor(Math.random() * 0x7fffffff);
  return `${Date.now()}_${rand}`;
}

export function wrapChatAlbumContent(caption: string, albumId?: string) {
  const body = (caption || "").trim();
  if (!albumId) return body;
  return `${ALBUM_PREFIX}${albumId}${ALBUM_SUFFIX}${body}`;
}

export function chatAlbumIdFromContent(content?: string | null) {
  const raw = content ?? "";
  if (!raw.startsWith(ALBUM_PREFIX)) return null;
  const end = raw.indexOf(ALBUM_SUFFIX, ALBUM_PREFIX.length);
  if (end <= ALBUM_PREFIX.length) return null;
  const id = raw.slice(ALBUM_PREFIX.length, end);
  return id || null;
}

export function stripChatAlbum(content?: string | null) {
  const raw = content ?? "";
  const id = chatAlbumIdFromContent(raw);
  if (!id) return raw;
  const marker = `${ALBUM_PREFIX}${id}${ALBUM_SUFFIX}`;
  if (raw.startsWith(marker)) return raw.slice(marker.length);
  return raw;
}

export function visibleChatCaption(content?: string | null) {
  return stripChatAlbum(content).trim();
}

function looksLikeFilename(value: string) {
  const text = value.trim();
  if (!text || text.includes("[[") || text.includes("/")) return false;
  return /^[^\\:*?"<>|]{1,200}\.[A-Za-z0-9]{2,8}$/.test(text);
}

export function applyChatFileName(msg: ChatMessage): ChatMessage {
  const fromFields = (msg.fileName || "").trim();
  const fromCache = lookupName(msg.id, msg.mediaUrl);
  const fromContent =
    msg.mediaType === "document" && looksLikeFilename(visibleChatCaption(msg.content))
      ? visibleChatCaption(msg.content)
      : "";
  const fileName = fromFields || fromCache || fromContent || undefined;
  if (fileName) {
    if (msg.id) persistName(msg.id, fileName);
    if (msg.mediaUrl) persistName(msg.mediaUrl, fileName);
  }
  return fileName && fileName !== msg.fileName ? { ...msg, fileName } : msg;
}

export function rememberChatUploadName(msg: ChatMessage, originalName: string): ChatMessage {
  const name = originalName.trim();
  if (!name) return applyChatFileName(msg);
  if (msg.id) persistName(msg.id, name);
  if (msg.mediaUrl) persistName(msg.mediaUrl, name);
  return applyChatFileName({ ...msg, fileName: name });
}

export function chatDocumentLabel(msg: ChatMessage) {
  const named = (msg.fileName || "").trim();
  if (named) return named;
  const caption = visibleChatCaption(msg.content);
  if (looksLikeFilename(caption)) return caption;
  return "Document attachment";
}

export function pendingFromFiles(list: FileList | File[], kind: "media" | "document"): PendingChatFile[] {
  const files = Array.from(list);
  const out: PendingChatFile[] = [];
  for (const file of files) {
    const isImage = file.type.startsWith("image/");
    const isVideo = file.type.startsWith("video/");
    if (kind === "media" && !isImage && !isVideo) continue;
    if (kind === "document" && (isImage || isVideo)) continue;
    const mediaType: PendingChatFile["mediaType"] = isImage
      ? "image"
      : isVideo
      ? "video"
      : file.type.startsWith("audio/")
      ? "voice"
      : "document";
    out.push({
      key: `${file.name}-${file.size}-${file.lastModified}-${Math.random()}`,
      file,
      mediaType,
      caption: "",
      previewUrl: isImage ? URL.createObjectURL(file) : undefined,
    });
  }
  return out;
}

export function revokePendingPreviews(items: PendingChatFile[]) {
  for (const item of items) {
    if (item.previewUrl) URL.revokeObjectURL(item.previewUrl);
  }
}

export function chatDayKey(iso?: string) {
  const d = iso ? new Date(iso) : new Date();
  if (Number.isNaN(d.getTime())) return "";
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

export function chatDayLabel(iso?: string) {
  const d = iso ? new Date(iso) : new Date();
  if (Number.isNaN(d.getTime())) return "";
  const start = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const diff = Math.round((today - start) / 86400000);
  if (diff === 0) return "Today";
  if (diff === 1) return "Yesterday";
  return d.toLocaleDateString(undefined, { month: "long", day: "numeric", year: "numeric" });
}

export function chatImageUrls(messages: ChatMessage[]) {
  return messages.map((m) => m.mediaUrl).filter((url): url is string => Boolean(url));
}

export function withChatDayPills(bubbles: ChatBubble[]) {
  let last = "";
  return bubbles.map((block) => {
    const message = block.kind === "album" ? block.messages[0] : block.message;
    const key = chatDayKey(message?.createdAt);
    const label = key && key !== last ? chatDayLabel(message?.createdAt) : null;
    if (key) last = key;
    return { block, dayLabel: label };
  });
}

export function groupChatBubbles(messages: ChatMessage[]): ChatBubble[] {
  const out: ChatBubble[] = [];
  let i = 0;
  while (i < messages.length) {
    const m = messages[i];
    const albumId = chatAlbumIdFromContent(m.content);
    const groupable =
      m.mediaType === "image" &&
      Boolean(m.mediaUrl) &&
      Boolean(albumId) &&
      !visibleChatCaption(m.content);
    if (groupable && albumId) {
      const batch = [m];
      let j = i + 1;
      while (j < messages.length) {
        const n = messages[j];
        const nextId = chatAlbumIdFromContent(n.content);
        if (
          n.mediaType === "image" &&
          n.mediaUrl &&
          n.senderId === m.senderId &&
          nextId === albumId &&
          !visibleChatCaption(n.content)
        ) {
          batch.push(n);
          j += 1;
        } else {
          break;
        }
      }
      if (batch.length > 1) {
        out.push({ kind: "album", messages: batch });
        i = j;
        continue;
      }
    }
    out.push({ kind: "single", message: m });
    i += 1;
  }
  return out;
}

export function orderPendingForSend(items: PendingChatFile[]) {
  const uncaptionedImages = items.filter((item) => item.mediaType === "image" && !item.caption.trim());
  const rest = items.filter((item) => !(item.mediaType === "image" && !item.caption.trim()));
  return [...uncaptionedImages, ...rest];
}

export function contentsForPending(items: PendingChatFile[]) {
  const uncaptionedImages = items.filter((item) => item.mediaType === "image" && !item.caption.trim());
  const albumId = uncaptionedImages.length > 1 ? newChatAlbumId() : undefined;
  return items.map((item) => {
    if (item.mediaType === "document") return item.file.name;
    if (item.mediaType === "image" && !item.caption.trim() && albumId) {
      return wrapChatAlbumContent("", albumId);
    }
    return item.caption.trim();
  });
}
