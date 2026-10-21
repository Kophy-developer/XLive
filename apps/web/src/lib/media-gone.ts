import type { QueryClient } from "@tanstack/react-query";
import type { FeedItem } from "./types";

const gone = new Set<string>();
const listeners = new Set<() => void>();

export function isFeedItemGone(id?: string | null) {
  return Boolean(id && gone.has(id));
}

export function subscribeGoneMedia(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function keepVisibleFeedItems(items: FeedItem[]) {
  return items.filter((item) => item?.id && !isFeedItemGone(item.id));
}

function stripIdFromUnknown(data: unknown, id: string): unknown {
  if (!data || typeof data !== "object") return data;
  const record = data as {
    pages?: { items?: FeedItem[]; videos?: FeedItem[]; clips?: FeedItem[] }[];
    items?: FeedItem[];
    videos?: FeedItem[];
    clips?: FeedItem[];
  };
  if (Array.isArray(record.pages)) {
    return {
      ...record,
      pages: record.pages.map((page) => ({
        ...page,
        items: Array.isArray(page.items) ? page.items.filter((item) => item.id !== id) : page.items,
        videos: Array.isArray(page.videos) ? page.videos.filter((item) => item.id !== id) : page.videos,
        clips: Array.isArray(page.clips) ? page.clips.filter((item) => item.id !== id) : page.clips,
      })),
    };
  }
  const next = { ...record };
  if (Array.isArray(next.items)) next.items = next.items.filter((item) => item.id !== id);
  if (Array.isArray(next.videos)) next.videos = next.videos.filter((item) => item.id !== id);
  if (Array.isArray(next.clips)) next.clips = next.clips.filter((item) => item.id !== id);
  return next;
}

export function markFeedItemGone(id: string, queryClient?: QueryClient) {
  if (!id || gone.has(id)) {
    if (queryClient) {
      for (const key of ["feed", "explore-feed", "user-content", "hashtag", "explore-search"]) {
        queryClient.setQueriesData({ queryKey: [key] }, (old) => stripIdFromUnknown(old, id));
      }
    }
    return;
  }
  gone.add(id);
  if (queryClient) {
    for (const key of ["feed", "explore-feed", "user-content", "hashtag", "explore-search"]) {
      queryClient.setQueriesData({ queryKey: [key] }, (old) => stripIdFromUnknown(old, id));
    }
  }
  listeners.forEach((listener) => listener());
}
