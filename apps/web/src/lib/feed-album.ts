import type { FeedItem } from "./types";

const ALBUM_PREFIX = "\u2063xlive_album:";
const ALBUM_SUFFIX = "\u2063";

export function newFeedAlbumId() {
  const rand = Math.floor(Math.random() * 0x7fffffff);
  return `${Date.now()}_${rand}`;
}

export function wrapFeedAlbumCaption(caption: string | undefined, albumId: string) {
  const body = (caption ?? "").trim();
  return `${ALBUM_PREFIX}${albumId}${ALBUM_SUFFIX}${body}`;
}

export function feedAlbumIdFromTitle(title?: string | null) {
  const raw = title ?? "";
  if (!raw.startsWith(ALBUM_PREFIX)) return null;
  const end = raw.indexOf(ALBUM_SUFFIX, ALBUM_PREFIX.length);
  if (end <= ALBUM_PREFIX.length) return null;
  const id = raw.slice(ALBUM_PREFIX.length, end);
  return id || null;
}

export function stripFeedAlbumMarker(title?: string | null) {
  const raw = title ?? "";
  const id = feedAlbumIdFromTitle(raw);
  if (!id) return raw;
  const marker = `${ALBUM_PREFIX}${id}${ALBUM_SUFFIX}`;
  if (raw.startsWith(marker)) {
    const rest = raw.slice(marker.length).trim();
    return rest;
  }
  return raw;
}

export function displayFeedCaption(item: Pick<FeedItem, "caption" | "title" | "albumSlides">) {
  const texts = [item.caption, item.title, ...(item.albumSlides ?? []).flatMap((slide) => [slide.caption, slide.title])];
  for (const raw of texts) {
    const text = stripFeedAlbumMarker(raw || "").trim();
    if (text && text !== "Untitled") return text;
  }
  const fallback = stripFeedAlbumMarker(item.caption || item.title || "").trim();
  return fallback || "Untitled";
}

function albumCaptionFromSlides(slides: FeedItem[]) {
  for (const slide of slides) {
    const text = stripFeedAlbumMarker(slide.caption || slide.title || "").trim();
    if (text && text !== "Untitled") return text;
  }
  return "";
}

function isAlbumMediaCandidate(item: FeedItem) {
  if (item.type === "live" || item.isLive) return false;
  if (!item.id) return false;
  if (item.mediaType === "image") return true;
  if (item.mediaType === "video") return true;
  return item.type === "video" || item.type === "clip" || item.type === "post";
}

function withDisplayTitle(item: FeedItem): FeedItem {
  const caption = stripFeedAlbumMarker(item.caption || item.title || "");
  return {
    ...item,
    caption: caption || undefined,
    title: caption || item.title,
  };
}

function copyWithAlbumSlides(item: FeedItem, slides: FeedItem[]): FeedItem {
  const lead = slides[0] ?? item;
  const caption = albumCaptionFromSlides(slides);
  return {
    ...lead,
    caption: caption || lead.caption,
    title: caption || lead.title,
    albumSlides: slides,
  };
}

export function albumSlidesOf(item: FeedItem) {
  if (item.albumSlides && item.albumSlides.length > 1) return item.albumSlides;
  return [item];
}

export function feedSaveTargetIds(item: Pick<FeedItem, "id" | "albumSlides">) {
  const slides = item.albumSlides && item.albumSlides.length > 1 ? item.albumSlides : [item];
  const seen = new Set<string>();
  const ids: string[] = [];
  for (const slide of slides) {
    const id = String(slide.id || "").trim();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    ids.push(id);
  }
  return ids;
}

export function albumContainsId(item: FeedItem, id: string) {
  if (item.id === id) return true;
  return Boolean(item.albumSlides?.some((slide) => slide.id === id));
}

export function slideIndexInAlbum(item: FeedItem, id: string) {
  const slides = albumSlidesOf(item);
  const idx = slides.findIndex((slide) => slide.id === id);
  return idx >= 0 ? idx : 0;
}

export function coalesceFeedAlbums(items: FeedItem[]) {
  if (!items.length) return items;
  const unique: FeedItem[] = [];
  const seenIds = new Set<string>();
  for (const item of items) {
    if (item.albumSlides && item.albumSlides.length > 1) {
      unique.push(item);
      continue;
    }
    if (!item.id || seenIds.has(item.id)) continue;
    seenIds.add(item.id);
    unique.push(item);
  }

  const groups = new Map<string, FeedItem[]>();
  for (const item of unique) {
    if (item.albumSlides && item.albumSlides.length > 1) continue;
    const albumId = feedAlbumIdFromTitle(item.title) || feedAlbumIdFromTitle(item.caption);
    if (!albumId || !isAlbumMediaCandidate(item)) continue;
    const list = groups.get(albumId) ?? [];
    list.push(withDisplayTitle(item));
    groups.set(albumId, list);
  }

  const emitted = new Set<string>();
  const out: FeedItem[] = [];
  for (const item of unique) {
    if (item.albumSlides && item.albumSlides.length > 1) {
      out.push(item);
      continue;
    }
    const albumId = feedAlbumIdFromTitle(item.title) || feedAlbumIdFromTitle(item.caption);
    if (albumId && isAlbumMediaCandidate(item)) {
      if (emitted.has(albumId)) continue;
      emitted.add(albumId);
      const slides = groups.get(albumId) ?? [withDisplayTitle(item)];
      if (slides.length === 1) {
        out.push(slides[0]);
        continue;
      }
      out.push(copyWithAlbumSlides(slides[0], slides));
      continue;
    }
    out.push(withDisplayTitle(item));
  }
  return out;
}
