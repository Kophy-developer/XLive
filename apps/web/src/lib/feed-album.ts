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
  const out: FeedItem[] = [];
  let i = 0;
  while (i < items.length) {
    const current = items[i];
    if (current.albumSlides && current.albumSlides.length > 1) {
      out.push(current);
      i += 1;
      continue;
    }

    const albumId = feedAlbumIdFromTitle(current.title) || feedAlbumIdFromTitle(current.caption);
    if (albumId && isAlbumMediaCandidate(current)) {
      const slides = [withDisplayTitle(current)];
      let j = i + 1;
      while (j < items.length) {
        const next = items[j];
        const nextId = feedAlbumIdFromTitle(next.title) || feedAlbumIdFromTitle(next.caption);
        if (nextId !== albumId || !isAlbumMediaCandidate(next)) break;
        slides.push(withDisplayTitle(next));
        j += 1;
      }
      out.push(copyWithAlbumSlides(slides[0], slides));
      i = j;
      continue;
    }

    out.push(withDisplayTitle(current));
    i += 1;
  }
  return out;
}
