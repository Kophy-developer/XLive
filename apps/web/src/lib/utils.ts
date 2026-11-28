import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import { config } from "./config";
import type { FeedItem } from "./types";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function isOwnFeedItem(
  item: Pick<FeedItem, "isOwner" | "creatorId" | "creator">,
  userId?: string | null
) {
  if (!userId) return false;
  if (item.isOwner) return true;
  if (item.creatorId && item.creatorId === userId) return true;
  if (item.creator?.id && item.creator.id === userId) return true;
  return false;
}

export function formatCount(value: number): string {
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K`;
  return String(value);
}

const FAKE_HANDLES = new Set([
  "creator",
  "user",
  "unknown",
  "guest",
  "null",
  "undefined",
  "anonymous",
]);

export function publicHandle(
  input?:
    | string
    | null
    | {
        username?: string | null;
        handle?: string | null;
        userName?: string | null;
        displayName?: string | null;
        name?: string | null;
        email?: string | null;
      }
): string {
  const candidates: unknown[] =
    typeof input === "string" || !input
      ? [input]
      : [input.username, input.handle, input.userName, input.email];
  for (const raw of candidates) {
    let value = String(raw ?? "").trim().replace(/^@+/, "");
    if (!value) continue;
    if (value.includes("@") && value.includes(".")) {
      value = value.split("@")[0] || value;
    }
    if (/\s/.test(value)) continue;
    if (FAKE_HANDLES.has(value.toLowerCase())) continue;
    if (value.length < 2) continue;
    return value;
  }
  return "";
}

export function handleLabel(
  input?: Parameters<typeof publicHandle>[0],
  fallback = "user"
): string {
  const handle = publicHandle(input);
  return `@${handle || fallback}`;
}

const IMAGE_EXT = /\.(jpg|jpeg|png|webp|gif|heic|heif|avif|bmp)(\?|$)/i;
const VIDEO_EXT = /\.(mp4|m4v|mov|webm|mkv|m3u8|mpd)(\?|$)/i;
const CLOUDINARY_UPLOAD = /^(https?:\/\/res\.cloudinary\.com\/[^/]+)\/(?:video|image)\/upload\/(.*)$/i;

export function looksLikeVideoUrl(src?: string | null) {
  if (!src) return false;
  const s = src.toLowerCase();
  if (s.includes("/video/upload/")) return true;
  return VIDEO_EXT.test(s);
}

export function looksLikeImageUrl(src?: string | null) {
  if (!src) return false;
  const s = src.toLowerCase();
  if (looksLikeVideoUrl(s) && !IMAGE_EXT.test(s)) return false;
  if (s.includes("/image/upload/")) return true;
  return IMAGE_EXT.test(s);
}

export function isImageFeedItem(item: Pick<FeedItem, "mediaType" | "mediaUrl" | "streamUrl" | "type">, url?: string) {
  const src = url || item.mediaUrl || item.streamUrl || "";
  if (looksLikeVideoUrl(src) && !IMAGE_EXT.test(src)) return false;
  if (item.type === "video" || item.type === "clip") return false;
  if (item.mediaType === "video") return false;
  if (item.mediaType === "image") return true;
  return looksLikeImageUrl(src);
}

export function isRemovedFeedRecord(raw: Record<string, unknown>) {
  const d = (raw.data && typeof raw.data === "object" ? raw.data : raw) as Record<string, unknown>;
  if (d.isDeleted === true || raw.isDeleted === true || d.deleted === true || raw.deleted === true) return true;
  if (d.deletedAt || raw.deletedAt) return true;
  const status = String(d.status ?? raw.status ?? "").toLowerCase();
  return status === "deleted" || status === "removed";
}

function isVideoFileUrl(src?: string | null) {
  if (!src) return false;
  if (looksLikeVideoUrl(src) && !IMAGE_EXT.test(src)) return true;
  return looksLikeVideoUrl(src) && !looksLikeImageUrl(src);
}

export function pickPreferredMediaUrl(...values: (string | undefined)[]) {
  const urls = values.filter((value): value is string => Boolean(value && value.trim())).map((value) => value.trim());
  return urls.find((url) => isVideoFileUrl(url)) || urls.find((url) => !looksLikeImageUrl(url)) || urls[0];
}

export function pickMediaUrl(raw: Record<string, unknown>, nested?: Record<string, unknown>) {
  const d = nested ?? {};
  return pickPreferredMediaUrl(
    d.streamUrl as string | undefined,
    raw.streamUrl as string | undefined,
    d.mediaUrl as string | undefined,
    raw.mediaUrl as string | undefined,
    d.videoUrl as string | undefined,
    raw.videoUrl as string | undefined,
    d.playbackUrl as string | undefined,
    raw.playbackUrl as string | undefined,
    d.fileUrl as string | undefined,
    raw.fileUrl as string | undefined,
    d.hlsUrl as string | undefined,
    raw.hlsUrl as string | undefined,
    d.sourceUrl as string | undefined,
    raw.sourceUrl as string | undefined,
    d.url as string | undefined,
    raw.url as string | undefined
  );
}

export function pickThumbnailUrl(raw: Record<string, unknown>, nested?: Record<string, unknown>, stream?: Record<string, unknown>) {
  const d = nested ?? {};
  const s = stream ?? {};
  const candidates = [
    d.thumbnailUrl,
    raw.thumbnailUrl,
    d.previewUrl,
    raw.previewUrl,
    d.coverUrl,
    raw.coverUrl,
    d.posterUrl,
    raw.posterUrl,
    s.thumbnailUrl,
    d.imageUrl,
    raw.imageUrl,
  ];
  for (const value of candidates) {
    if (typeof value !== "string" || !value.trim()) continue;
    const url = value.trim();
    if (looksLikeVideoUrl(url) && !looksLikeImageUrl(url)) continue;
    return url;
  }
  return undefined;
}

export function isPlayableFeedItem(item: FeedItem) {
  if (!item?.id) return false;
  if (item.type === "live" || item.isLive) return true;
  return Boolean(item.mediaUrl || item.streamUrl || item.thumbnailUrl || item.previewUrl);
}

function hostFileUrl(path: string) {
  const clean = path.replace(/^\/+/, "");
  return `${config.apiBaseUrl}/${clean}`;
}

function isHostStoredPath(path: string) {
  const clean = path.replace(/^\/+/, "").toLowerCase();
  return (
    clean.startsWith("uploads/") ||
    clean.startsWith("api/uploads/") ||
    clean.startsWith("static/") ||
    clean.startsWith("media/")
  );
}

function cloudinaryVideoFromHostUpload(path: string) {
  const match = path.match(/\/(?:api\/)?uploads\/(x-live\/[^/?#]+)/i) || path.match(/^(?:api\/)?uploads\/(x-live\/[^/?#]+)/i);
  if (!match) return "";
  const publicId = match[1].replace(/\.[a-z0-9]+$/i, "");
  return `https://res.cloudinary.com/${config.cloudinaryCloud}/video/upload/f_mp4/${publicId}`;
}

function asCloudinaryImage(url: string, transform: string) {
  const match = url.match(CLOUDINARY_UPLOAD);
  if (!match) return url;
  let rest = match[2].replace(/^(?:f_mp4\/)+/i, "");
  if (transform && !rest.toLowerCase().startsWith(transform.toLowerCase())) {
    rest = `${transform}/${rest}`;
  } else if (!/(?:^|\/|,)f_auto(?:,|\/|$)/i.test(rest)) {
    rest = `f_auto,q_auto/${rest}`;
  }
  return `${match[1]}/image/upload/${rest}`;
}

function isSignedCloudinaryUrl(url: string) {
  return /\/s--[^/]+--\//.test(url);
}

export function resolveMediaSrc(path?: string | null, kind: "image" | "video" = "image") {
  if (!path || typeof path !== "string") return "";
  const trimmed = path.trim();
  if (!trimmed) return "";
  if (trimmed.startsWith("//")) return `https:${trimmed}`;
  if (isSignedCloudinaryUrl(trimmed)) return trimmed;
  if (/^https?:\/\//i.test(trimmed)) {
    if (kind === "image" && /\/video\/upload\//i.test(trimmed)) {
      return trimmed.replace(/\/video\/upload\//i, "/image/upload/");
    }
    return trimmed;
  }
  if (isHostStoredPath(trimmed)) return hostFileUrl(trimmed);
  const cleanPath = trimmed.replace(/^\/+/, "");
  if (kind === "video") {
    return `https://res.cloudinary.com/${config.cloudinaryCloud}/video/upload/${cleanPath}`;
  }
  return `https://res.cloudinary.com/${config.cloudinaryCloud}/image/upload/${cleanPath}`;
}

export function originalMediaUrl(path?: string | null) {
  if (!path || typeof path !== "string") return "";
  const trimmed = path.trim();
  if (!trimmed) return "";
  if (trimmed.startsWith("//")) return `https:${trimmed}`;
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  if (isHostStoredPath(trimmed)) return hostFileUrl(trimmed);
  const cleanPath = trimmed.replace(/^\/+/, "");
  return `https://res.cloudinary.com/${config.cloudinaryCloud}/image/upload/${cleanPath}`;
}

export function cloudinaryUrl(path?: string | null, transform = "c_fill,w_400,h_400,g_auto,f_auto,q_auto") {
  const resolved = resolveMediaSrc(path, "image");
  if (!resolved) return "";
  if (isSignedCloudinaryUrl(resolved)) return resolved;
  if (CLOUDINARY_UPLOAD.test(resolved)) {
    const withAuto = /f_auto/i.test(transform) ? transform : `${transform},f_auto,q_auto`;
    return asCloudinaryImage(resolved, withAuto);
  }
  return resolved;
}

export function playbackVideoUrl(path?: string | null): string {
  if (!path || typeof path !== "string") return "";
  const trimmed = path.trim();
  if (!trimmed) return "";
  const fromHost = cloudinaryVideoFromHostUpload(trimmed);
  if (fromHost) return fromHost;
  if (isSignedCloudinaryUrl(trimmed)) return trimmed;
  const resolved = /^https?:\/\//i.test(trimmed) || trimmed.startsWith("//")
    ? resolveMediaSrc(trimmed, "video")
    : isHostStoredPath(trimmed)
      ? hostFileUrl(trimmed)
      : resolveMediaSrc(trimmed, "video");
  if (looksLikeImageUrl(resolved) && IMAGE_EXT.test(resolved) && !VIDEO_EXT.test(resolved)) {
    return resolved;
  }
  const match = resolved.match(CLOUDINARY_UPLOAD);
  if (!match) return resolved;
  const rest = match[2];
  if (/\.m3u8(\?|$)/i.test(rest) || /\.mpd(\?|$)/i.test(rest)) return resolved;
  if (/(?:^|\/|,)f_mp4(?:,|\/|$)/i.test(rest)) {
    return `${match[1]}/video/upload/${rest}`;
  }
  return `${match[1]}/video/upload/f_mp4/${rest}`;
}
