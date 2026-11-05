import { create } from "zustand";
import type { FeedItem, XLiveUser } from "./types";
import { isFeedItemGone } from "./media-gone";
import { albumContainsId, coalesceFeedAlbums } from "./feed-album";

type AuthState = {
  user: XLiveUser | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  unreadTotal: number;
  notificationUnread: number;
  setUser: (user: XLiveUser | null) => void;
  setLoading: (loading: boolean) => void;
  setAuthenticated: (value: boolean) => void;
  setUnreadTotal: (total: number) => void;
  setNotificationUnread: (total: number) => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isLoading: true,
  isAuthenticated: false,
  unreadTotal: 0,
  notificationUnread: 0,
  setUser: (user) => set({ user }),
  setLoading: (isLoading) => set({ isLoading }),
  setAuthenticated: (isAuthenticated) => set({ isAuthenticated }),
  setUnreadTotal: (unreadTotal) => set({ unreadTotal }),
  setNotificationUnread: (notificationUnread) => set({ notificationUnread }),
}));

type UiState = {
  theme: "light" | "dark" | "system";
  createSheetOpen: boolean;
  setTheme: (theme: "light" | "dark" | "system") => void;
  setCreateSheetOpen: (open: boolean) => void;
};

export const useUiStore = create<UiState>((set) => ({
  theme: "dark",
  createSheetOpen: false,
  setTheme: (theme) => set({ theme }),
  setCreateSheetOpen: (createSheetOpen) => set({ createSheetOpen }),
}));

export type ActiveCallInfo = {
  callId: string;
  callType: "audio" | "video";
  chatId?: string;
  groupId?: string;
  title: string;
  avatarUrl?: string;
  startedAt?: number;
};

type CallState = {
  activeCallId: string | null;
  callType: "audio" | "video" | null;
  activeCall: ActiveCallInfo | null;
  setActiveCall: (callId: string | null, callType?: "audio" | "video" | null, details?: Partial<ActiveCallInfo>) => void;
  clearActiveCall: () => void;
};

export const useCallStore = create<CallState>((set) => ({
  activeCallId: null,
  callType: null,
  activeCall: null,
  setActiveCall: (activeCallId, callType = null, details) =>
    set({
      activeCallId,
      callType,
      activeCall:
        activeCallId && callType
          ? {
              callId: activeCallId,
              callType,
              title: details?.title || "Active Call",
              chatId: details?.chatId,
              groupId: details?.groupId,
              avatarUrl: details?.avatarUrl,
              startedAt: details?.startedAt || Date.now(),
            }
          : null,
    }),
  clearActiveCall: () => set({ activeCallId: null, callType: null, activeCall: null }),
}));

type FeedViewerState = {
  items: FeedItem[];
  index: number;
  fetchMore: (() => Promise<FeedItem[]>) | null;
  open: (items: FeedItem[], index: number, fetchMore?: () => Promise<FeedItem[]>) => void;
  setIndex: (index: number) => void;
  mergeItems: (items: FeedItem[]) => void;
  removeItem: (id: string) => FeedItem | undefined;
  clear: () => void;
};

function uniqueFeedItems(items: FeedItem[]) {
  const grouped = coalesceFeedAlbums(items);
  const nested = new Set<string>();
  for (const item of grouped) {
    if (item.albumSlides && item.albumSlides.length > 1) {
      for (const slide of item.albumSlides) {
        if (slide.id && slide.id !== item.id) nested.add(slide.id);
      }
    }
  }
  const seen = new Set<string>();
  const list: FeedItem[] = [];
  for (const item of grouped) {
    if (!item?.id || seen.has(item.id) || nested.has(item.id)) continue;
    if (item.type === "live" || item.isLive) continue;
    if (isFeedItemGone(item.id)) continue;
    if (item.albumSlides?.some((slide) => isFeedItemGone(slide.id))) {
      const slides = item.albumSlides.filter((slide) => slide.id && !isFeedItemGone(slide.id));
      if (slides.length <= 1) {
        const only = slides[0];
        if (!only?.id || seen.has(only.id)) continue;
        seen.add(only.id);
        list.push(only);
        continue;
      }
      seen.add(slides[0].id);
      list.push({ ...slides[0], albumSlides: slides });
      continue;
    }
    seen.add(item.id);
    list.push(item);
  }
  return list;
}

export const useFeedViewerStore = create<FeedViewerState>((set, get) => ({
  items: [],
  index: 0,
  fetchMore: null,
  open: (items, index, fetchMore) => {
    const wanted = items[index]?.id;
    const list = uniqueFeedItems(items);
    let safeIndex = wanted ? list.findIndex((i) => albumContainsId(i, wanted)) : -1;
    if (safeIndex < 0) safeIndex = Math.max(0, Math.min(index, Math.max(0, list.length - 1)));
    set({ items: list, index: safeIndex, fetchMore: fetchMore ?? null });
  },
  setIndex: (index) => {
    const { items } = get();
    if (!items.length) return;
    set({ index: Math.max(0, Math.min(index, items.length - 1)) });
  },
  mergeItems: (incoming) => {
    const { items, index } = get();
    const list = uniqueFeedItems([...items, ...incoming]);
    const currentId = items[index]?.id;
    const found = currentId ? list.findIndex((i) => albumContainsId(i, currentId)) : -1;
    const nextIndex = found >= 0 ? found : Math.max(0, Math.min(index, Math.max(0, list.length - 1)));
    set({ items: list, index: nextIndex });
  },
  removeItem: (id) => {
    const { items, index } = get();
    const list: FeedItem[] = [];
    for (const item of items) {
      if (item.id === id && !(item.albumSlides && item.albumSlides.length > 1)) continue;
      if (item.albumSlides && item.albumSlides.length > 1) {
        const slides = item.albumSlides.filter((slide) => slide.id !== id);
        if (!slides.length) continue;
        if (slides.length === 1) {
          list.push(slides[0]);
          continue;
        }
        list.push({ ...slides[0], albumSlides: slides });
        continue;
      }
      list.push(item);
    }
    if (!list.length) {
      set({ items: [], index: 0 });
      return undefined;
    }
    const nextIndex = Math.min(index, list.length - 1);
    set({ items: list, index: nextIndex });
    return list[nextIndex];
  },
  clear: () => set({ items: [], index: 0, fetchMore: null }),
}));
