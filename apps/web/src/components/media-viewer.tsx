"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import type { FeedItem, MediaComment } from "@/lib/types";
import { normalizeFeedItem, followUser, unfollowUser, getUserProfile, getForYouFeed, getUserContent } from "@/lib/api/feed";
import { getClip, getVideo, deleteOwnedMedia, getOwnerInsightsViews } from "@/lib/api/misc";
import {
  countVisibleComments,
  createComment,
  deleteComment,
  getLikeSummary,
  likeMedia,
  listAllComments,
  mediaTargetType,
  rememberCommentCount,
  unlikeMedia,
} from "@/lib/api/social";
import {
  COMMENT_EMOJI_PACK,
  QUICK_REACTION_CODES,
  decodeCommentText,
  extractMediaUrls,
  glyphForCode,
  isReactionComment,
  parseReaction,
  reactionToken,
  textWithoutMedia,
  composeCommentContent,
} from "@/lib/comment-emoji";
import { onSocketEvent } from "@/lib/socket";
import { useAuthStore, useFeedViewerStore } from "@/lib/stores";
import { cloudinaryUrl, cn, formatCount, handleLabel, isImageFeedItem, isOwnFeedItem, isRemovedFeedRecord, looksLikeImageUrl, looksLikeVideoUrl, originalMediaUrl, pickPreferredMediaUrl, playbackVideoUrl, publicHandle } from "@/lib/utils";
import { albumContainsId, albumSlidesOf, displayFeedCaption, slideIndexInAlbum } from "@/lib/feed-album";
import { markFeedItemGone } from "@/lib/media-gone";
import { GifPicker } from "@/components/gif-picker";
import { DeletePostDialog } from "@/components/delete-post-dialog";
import { MediaOverlayIcon } from "@/components/media-overlay-icon";
import { isCreatorLiveNow, refreshLiveNowCreators } from "@/lib/live-now";
import {
  Eye,
  ChevronDown,
  ChevronUp,
  Heart,
  Lock,
  MessageCircle,
  Play,
  Send,
  Share2,
  Smile,
  Trash2,
  X,
  Loader2,
  Bookmark,
} from "lucide-react";
import { isSavedLocal, toggleSavedMedia } from "@/lib/saved-media";

function unwrapMediaRecord(raw: Record<string, unknown> | null | undefined): Record<string, unknown> | null {
  if (!raw || typeof raw !== "object") return null;
  const nested = (raw.data && typeof raw.data === "object" && !Array.isArray(raw.data)
    ? raw.data
    : raw) as Record<string, unknown>;
  if (nested.video && typeof nested.video === "object") return nested.video as Record<string, unknown>;
  if (nested.clip && typeof nested.clip === "object") return nested.clip as Record<string, unknown>;
  return nested;
}

function recordFromPayload(raw: Record<string, unknown> | null | undefined, type: string): FeedItem | "removed" | null {
  const inner = unwrapMediaRecord(raw);
  if (!inner) return null;
  if (isRemovedFeedRecord(inner) || (raw && isRemovedFeedRecord(raw))) return "removed";
  const keys = Object.keys(inner);
  if (!keys.length) return null;
  if (inner.success === false && !inner.id && !inner._id && !inner.mediaUrl && !inner.streamUrl) return null;
  return normalizeFeedItem({ ...inner, type });
}

async function loadMediaDetail(id: string, hint?: FeedItem["type"]): Promise<FeedItem | "removed" | null> {
  const tryVideo = async () => {
    const v = await getVideo(id);
    return recordFromPayload(v, hint === "clip" ? "clip" : String(v?.type || "video"));
  };
  const tryClip = async () => {
    const c = await getClip(id);
    return recordFromPayload(c, "clip");
  };
  const first = hint === "clip" ? tryClip : tryVideo;
  const second = hint === "clip" ? tryVideo : tryClip;
  try {
    const item = await first();
    if (item === "removed") return "removed";
    if (item) return item;
  } catch {
  }
  try {
    const item = await second();
    if (item === "removed") return "removed";
    if (item) return item;
  } catch {
  }
  return null;
}

function pickUrl(...values: (string | undefined)[]) {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return undefined;
}

function mergeItem(base: FeedItem, extra: FeedItem): FeedItem {
  const still = extra.mediaType === "image" || base.mediaType === "image";
  const mediaUrl = still
    ? pickPreferredMediaUrl(base.mediaUrl, extra.mediaUrl)
    : pickPreferredMediaUrl(base.mediaUrl, extra.mediaUrl, extra.streamUrl, base.streamUrl);
  const streamUrl = still
    ? undefined
    : pickPreferredMediaUrl(base.streamUrl, extra.streamUrl, extra.mediaUrl, base.mediaUrl);
  const file = mediaUrl || streamUrl;
  return {
    ...base,
    ...extra,
    id: base.id || extra.id,
    type: extra.type || base.type,
    caption: extra.caption || base.caption,
    title: extra.title || base.title,
    mediaUrl,
    streamUrl,
    thumbnailUrl: pickUrl(base.thumbnailUrl, extra.thumbnailUrl),
    previewUrl: pickUrl(base.previewUrl, extra.previewUrl),
    creator: extra.creator?.id || extra.creator?.username ? extra.creator : base.creator,
    creatorId: extra.creatorId || extra.creator?.id || base.creatorId || base.creator?.id,
    creatorName: extra.creatorName || extra.creator?.username || base.creatorName,
    creatorAvatarUrl: extra.creatorAvatarUrl || extra.creator?.avatarUrl || base.creatorAvatarUrl,
    likeCount: extra.likeCount ?? base.likeCount,
    viewCount: extra.viewCount ?? base.viewCount,
    commentCount: base.commentCount ?? extra.commentCount,
    mediaType: file && looksLikeVideoUrl(file) && !looksLikeImageUrl(file) ? "video" : extra.mediaType || base.mediaType,
    accessAllowed: extra.accessAllowed ?? base.accessAllowed,
    needsPurchase: extra.needsPurchase ?? base.needsPurchase,
    price: extra.price ?? base.price,
    isFollowing: extra.isFollowing ?? base.isFollowing,
    likedByMe: extra.likedByMe ?? base.likedByMe,
    isOwner: extra.isOwner ?? base.isOwner,
    albumSlides: base.albumSlides?.length ? base.albumSlides : extra.albumSlides,
  };
}

function creatorLabel(item: FeedItem) {
  return publicHandle(item.creator) || publicHandle(item.creatorName);
}

export function MediaReelViewer({ initialId }: { initialId: string }) {
  const router = useRouter();
  const me = useAuthStore((s) => s.user);
  const storeItems = useFeedViewerStore((s) => s.items);
  const storeIndex = useFeedViewerStore((s) => s.index);
  const fetchMore = useFeedViewerStore((s) => s.fetchMore);
  const setIndex = useFeedViewerStore((s) => s.setIndex);
  const mergeItems = useFeedViewerStore((s) => s.mergeItems);
  const openViewer = useFeedViewerStore((s) => s.open);
  const removeItem = useFeedViewerStore((s) => s.removeItem);
  const queryClient = useQueryClient();

  const [hydrated, setHydrated] = useState(false);
  const [details, setDetails] = useState<Record<string, FeedItem>>({});
  const [commentsOpen, setCommentsOpen] = useState(false);
  const [shareHint, setShareHint] = useState("");
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState("");
  const [slideIndex, setSlideIndex] = useState(0);
  const cooldownRef = useRef(0);
  const fetchingMoreRef = useRef(false);
  const wheelAccRef = useRef(0);
  const wheelXAccRef = useRef(0);
  const rootRef = useRef<HTMLDivElement>(null);
  const swipeRef = useRef({ x: 0, y: 0, active: false });

  useEffect(() => {
    setHydrated(true);
  }, []);

  const [liveRingReady, setLiveRingReady] = useState(false);
  useEffect(() => {
    void refreshLiveNowCreators().then(() => setLiveRingReady(true));
  }, []);

  useEffect(() => {
    if (!hydrated || !initialId) return;
    const state = useFeedViewerStore.getState();
    const existing = state.items.findIndex((i) => albumContainsId(i, initialId));
    if (existing >= 0) {
      if (existing !== state.index) state.setIndex(existing);
      return;
    }
    let cancelled = false;
    (async () => {
      const detail = await loadMediaDetail(initialId);
      if (cancelled) return;
      const listed = useFeedViewerStore.getState().items.findIndex((i) => albumContainsId(i, initialId));
      if (listed >= 0) {
        useFeedViewerStore.getState().setIndex(listed);
        return;
      }
      if (detail === "removed") {
        markFeedItemGone(initialId, queryClient);
      }
      const start = detail && detail !== "removed" ? detail : null;
      let extras: FeedItem[] = [];
      if (start?.creatorId) {
        try {
          extras = (await getUserContent(start.creatorId)).items;
        } catch {
        }
      }
      if (!extras.length) {
        try {
          extras = (await getForYouFeed(1)).items;
        } catch {
        }
      }
      if (cancelled) return;
      const seed = start ? [start, ...extras] : extras;
      const list = seed.filter((i) => i.id && !(detail === "removed" && i.id === initialId));
      const idx = list.findIndex((i) => albumContainsId(i, initialId));
      if (!list.length) {
        if (typeof window !== "undefined" && window.history.length > 1) {
          router.back();
        } else {
          router.push("/home");
        }
        return;
      }
      openViewer(list, Math.max(0, idx));
    })();
    return () => {
      cancelled = true;
    };
  }, [hydrated, initialId, openViewer, queryClient, router]);

  const items = storeItems;
  const index = items.length
    ? Math.max(0, Math.min(storeIndex, items.length - 1))
    : 0;
  const active = items[index];
  const slides = active ? albumSlidesOf(active) : [];
  const safeSlide = slides.length ? Math.max(0, Math.min(slideIndex, slides.length - 1)) : 0;
  const currentSlide = slides[safeSlide] ?? active;

  useEffect(() => {
    if (!active) return;
    setSlideIndex(slideIndexInAlbum(active, initialId));
  }, [active?.id, initialId]);

  const goSlide = useCallback(
    (next: number) => {
      if (slides.length <= 1) return;
      const clamped = Math.max(0, Math.min(next, slides.length - 1));
      if (clamped === safeSlide) return;
      setSlideIndex(clamped);
      const slide = slides[clamped];
      if (slide?.id) router.replace(`/media/${slide.id}`, { scroll: false });
    },
    [router, safeSlide, slides]
  );

  const goTo = useCallback(
    (next: number) => {
      if (!items.length) return;
      const now = Date.now();
      if (now - cooldownRef.current < 280) return;
      const clamped = Math.max(0, Math.min(next, items.length - 1));
      if (clamped === index) return;
      cooldownRef.current = now;
      setIndex(clamped);
      const nextItem = items[clamped];
      if (nextItem) {
        router.replace(`/media/${nextItem.id}`, { scroll: false });
      }
    },
    [index, items, router, setIndex]
  );

  const closeViewer = useCallback(() => {
    if (typeof window !== "undefined" && window.history.length > 1) {
      router.back();
    } else {
      router.push("/home");
    }
  }, [router]);

  const dropGone = useCallback(
    (id: string) => {
      markFeedItemGone(id, queryClient);
      const next = removeItem(id);
      if (next?.id) {
        router.replace(`/media/${next.id}`, { scroll: false });
      } else {
        closeViewer();
      }
    },
    [closeViewer, queryClient, removeItem, router]
  );

  useEffect(() => {
    if (!currentSlide?.id) return;
    const id = currentSlide.id;
    const type = currentSlide.type;
    const base = currentSlide;
    let cancelled = false;
    (async () => {
      const detail = await loadMediaDetail(id, type);
      if (cancelled) return;
      if (detail === "removed") {
        dropGone(id);
        return;
      }
      if (!detail) return;
      let merged = mergeItem(base, detail);
      if (!publicHandle(merged.creator) && !publicHandle(merged.creatorName) && merged.creatorId) {
        try {
          const profile = await getUserProfile(merged.creatorId);
          merged = {
            ...merged,
            creator: profile,
            creatorName: publicHandle(profile),
            creatorAvatarUrl: profile.avatarUrl || merged.creatorAvatarUrl,
            isFollowing: merged.isFollowing,
          };
        } catch {
        }
      }
      merged = { ...merged, albumSlides: active?.albumSlides };
      setDetails((prev) => ({ ...prev, [id]: mergeItem(prev[id] ?? base, merged) }));
    })();
    return () => {
      cancelled = true;
    };
  }, [active?.albumSlides, currentSlide?.id, currentSlide?.type, dropGone]);

  useEffect(() => {
    if (!items.length || !fetchMore) return;
    if (index < items.length - 2) return;
    if (fetchingMoreRef.current) return;
    fetchingMoreRef.current = true;
    fetchMore()
      .then((more) => {
        if (more?.length) mergeItems(more);
      })
      .catch(() => {})
      .finally(() => {
        fetchingMoreRef.current = false;
      });
  }, [fetchMore, index, items.length, mergeItems]);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "ArrowDown" || e.key === "j") {
        e.preventDefault();
        goTo(index + 1);
      } else if (e.key === "ArrowUp" || e.key === "k") {
        e.preventDefault();
        goTo(index - 1);
      } else if (e.key === "ArrowLeft") {
        e.preventDefault();
        goSlide(safeSlide - 1);
      } else if (e.key === "ArrowRight") {
        e.preventDefault();
        goSlide(safeSlide + 1);
      } else if (e.key === "Escape") {
        if (deleteOpen) {
          if (!deleting) {
            setDeleteOpen(false);
            setDeleteError("");
          }
        } else if (commentsOpen) setCommentsOpen(false);
        else closeViewer();
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [closeViewer, commentsOpen, deleteOpen, deleting, goSlide, goTo, index, safeSlide]);

  useEffect(() => {
    const el = rootRef.current;
    if (!el) return;
    function onNativeWheel(e: WheelEvent) {
      const target = e.target as HTMLElement | null;
      if (target?.closest("[data-comments-panel]")) return;
      e.preventDefault();
      const ax = Math.abs(e.deltaX);
      const ay = Math.abs(e.deltaY);
      if (slides.length > 1 && ax > ay && ax > 6) {
        wheelXAccRef.current += e.deltaX;
        if (Math.abs(wheelXAccRef.current) < 48) return;
        const dir = wheelXAccRef.current > 0 ? 1 : -1;
        wheelXAccRef.current = 0;
        goSlide(safeSlide + dir);
        return;
      }
      wheelAccRef.current += e.deltaY;
      if (Math.abs(wheelAccRef.current) < 40) return;
      const dir = wheelAccRef.current > 0 ? 1 : -1;
      wheelAccRef.current = 0;
      goTo(index + dir);
    }
    el.addEventListener("wheel", onNativeWheel, { passive: false });
    return () => el.removeEventListener("wheel", onNativeWheel);
  }, [goSlide, goTo, index, safeSlide, slides.length]);

  const item = currentSlide
    ? {
        ...(details[currentSlide.id] ?? currentSlide),
        albumSlides: active?.albumSlides,
        caption: displayFeedCaption(active ?? currentSlide),
        title: displayFeedCaption(active ?? currentSlide),
      }
    : undefined;
  const fileUrl = pickPreferredMediaUrl(item?.mediaUrl, item?.streamUrl);
  const thumb = item?.thumbnailUrl || item?.previewUrl;
  const playback =
    item && (item.mediaType === "image" || isImageFeedItem(item))
      ? [item.mediaUrl, item.thumbnailUrl, item.previewUrl].find((u) => looksLikeImageUrl(u)) || thumb
      : fileUrl || thumb;
  const locked = Boolean(item?.needsPurchase) || item?.accessAllowed === false;
  const itemTargetType = item ? mediaTargetType(item.type) : "video";

  const commentsQuery = useQuery({
    queryKey: ["media-comments", itemTargetType, item?.id],
    queryFn: () => listAllComments(itemTargetType, item!.id),
    enabled: Boolean(item?.id),
    refetchInterval: commentsOpen ? 3000 : false,
  });

  useEffect(() => {
    const comments = commentsQuery.data?.comments;
    if (!item?.id || !comments) return;
    const count = countVisibleComments(comments);
    rememberCommentCount(itemTargetType, item.id, count);
    setDetails((prev) => {
      const current = prev[item.id] ?? item;
      if (current.commentCount === count) return prev;
      return { ...prev, [item.id]: { ...current, commentCount: count } };
    });
  }, [commentsQuery.data, item, itemTargetType]);

  if (!hydrated || !item) {
    return (
      <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black">
        <div className="h-10 w-10 animate-pulse rounded-full brand-gradient" />
      </div>
    );
  }

  const name = creatorLabel(item);
  const handle = name ? handleLabel(name) : "";
  const avatar = item.creator?.avatarUrl || item.creatorAvatarUrl;
  const creatorId = item.creatorId || item.creator?.id;
  const creatorLiveRing =
    liveRingReady &&
    Boolean(creatorId && (item.isLive || item.type === "live" || isCreatorLiveNow(creatorId)));
  const isOwner = isOwnFeedItem(item, me?.id);
  const deleteKind = item.type === "clip" ? "clip" : "post";

  async function confirmDelete() {
    const target = item;
    if (!target?.id || deleting) return;
    setDeleting(true);
    setDeleteError("");
    try {
      await deleteOwnedMedia(target);
      markFeedItemGone(target.id, queryClient);
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["feed"] }),
        queryClient.invalidateQueries({ queryKey: ["explore-feed"] }),
        queryClient.invalidateQueries({ queryKey: ["user-content"] }),
      ]);
      setDeleteOpen(false);
      const next = removeItem(target.id);
      if (next?.id) {
        router.replace(`/media/${next.id}`, { scroll: false });
      } else {
        closeViewer();
      }
    } catch (err) {
      setDeleteError((err as Error).message || "Could not delete this post.");
    } finally {
      setDeleting(false);
    }
  }

  return (
    <div
      ref={rootRef}
      className="fixed inset-0 z-[90] flex bg-black text-white select-none"
    >
      <div className="absolute left-4 top-4 z-40">
        <button
          type="button"
          onClick={closeViewer}
          className="flex h-10 w-10 items-center justify-center rounded-full bg-black/45 text-white backdrop-blur-md transition hover:bg-black/70"
          aria-label="Close"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      {creatorId ? (
        <Link
          href={`/profile/${creatorId}`}
          className="absolute right-4 top-4 z-40 hidden max-w-[55%] items-center gap-2 rounded-full bg-black/35 py-1 pl-1 pr-3 backdrop-blur-md hover:bg-black/55 md:flex"
        >
          {avatar ? (
            <img
              src={cloudinaryUrl(avatar, "c_fill,w_72,h_72,g_face")}
              alt=""
              className="h-8 w-8 rounded-full object-cover"
            />
          ) : (
            <div className="flex h-8 w-8 items-center justify-center rounded-full brand-gradient text-xs font-bold">
              {(name || "U")[0]?.toUpperCase()}
            </div>
          )}
          <span className="truncate text-xs font-bold">{handle || "@user"}</span>
        </Link>
      ) : null}

      <div className="relative flex min-h-0 min-w-0 flex-1 items-stretch justify-center md:items-center">
        <div
          className={cn(
            "relative h-full w-full overflow-hidden bg-[#0b0b12] md:h-[min(92dvh,860px)] md:w-[min(100%,440px)] md:rounded-2xl md:shadow-2xl",
            slides.length > 1 && "touch-none"
          )}
          onPointerDown={(e) => {
            const hit = e.target as HTMLElement | null;
            if (hit?.closest("button,a,[data-album-dots],[data-media-zoomed]")) return;
            swipeRef.current = { x: e.clientX, y: e.clientY, active: true };
            e.currentTarget.setPointerCapture(e.pointerId);
          }}
          onPointerUp={(e) => {
            if (!swipeRef.current.active) return;
            swipeRef.current.active = false;
            try {
              e.currentTarget.releasePointerCapture(e.pointerId);
            } catch {
            }
            const dx = e.clientX - swipeRef.current.x;
            const dy = e.clientY - swipeRef.current.y;
            if (slides.length > 1 && Math.abs(dx) >= 36 && Math.abs(dx) > Math.abs(dy) * 1.1) {
              if (dx < 0) goSlide(safeSlide + 1);
              else goSlide(safeSlide - 1);
            }
          }}
          onPointerCancel={() => {
            swipeRef.current.active = false;
          }}
        >
          {locked ? (
            <div className="flex h-full flex-col items-center justify-center px-8 text-center">
              {thumb ? (
                <img src={cloudinaryUrl(thumb)} alt="" className="absolute inset-0 h-full w-full object-cover opacity-30 blur-xl" />
              ) : null}
              <div className="relative z-10 flex flex-col items-center">
                <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-amber-500/20 text-amber-400">
                  <Lock className="h-8 w-8" />
                </div>
                <h2 className="mt-4 text-xl font-bold">Exclusive Content</h2>
                <p className="mt-1.5 text-xs text-white/70">
                  Unlock for <span className="font-bold text-amber-400">{item.price ?? 5} coins</span>
                </p>
                <Link href="/wallet" className="mt-6 rounded-xl brand-gradient px-6 py-2.5 text-xs font-bold">
                  Top up Wallet to Unlock
                </Link>
              </div>
            </div>
          ) : playback ? (
            <ReelMedia
              item={item}
              playback={playback}
              thumb={thumb}
            />
          ) : (
            <div className="flex h-full flex-col items-center justify-center text-zinc-500">
              <Play className="h-10 w-10 opacity-40" />
              <p className="mt-3 text-sm">Media unavailable</p>
            </div>
          )}

          {slides.length > 1 ? (
            <div data-album-dots className="absolute inset-x-0 bottom-28 z-30 flex justify-center gap-2">
              {slides.map((slide, i) => (
                <button
                  key={slide.id || i}
                  type="button"
                  aria-label={`Go to media ${i + 1}`}
                  onClick={(e) => {
                    e.stopPropagation();
                    goSlide(i);
                  }}
                  className="flex h-6 w-6 items-center justify-center"
                >
                  <span className={cn("h-2 w-2 rounded-full", i === safeSlide ? "bg-white" : "bg-white/40")} />
                </button>
              ))}
            </div>
          ) : null}

          <div className="pointer-events-none absolute inset-x-0 bottom-0 z-30 bg-gradient-to-t from-black/70 via-black/20 to-transparent pb-6 pl-4 pr-20 pt-20">
            <div className="pointer-events-auto flex items-center gap-2.5">
              {creatorId ? (
                <Link href={`/profile/${creatorId}`} className="shrink-0">
                  {avatar ? (
                    <img
                      src={cloudinaryUrl(avatar, "c_fill,w_96,h_96,g_face")}
                      alt=""
                      className={cn(
                        "h-10 w-10 rounded-full object-cover",
                        creatorLiveRing ? "ring-2 ring-red-500" : "ring-2 ring-white/80"
                      )}
                    />
                  ) : (
                    <div className="flex h-10 w-10 items-center justify-center rounded-full brand-gradient text-sm font-bold">
                      {(name || "U")[0]?.toUpperCase()}
                    </div>
                  )}
                </Link>
              ) : avatar ? (
                <img
                  src={cloudinaryUrl(avatar, "c_fill,w_96,h_96,g_face")}
                  alt=""
                  className={cn(
                    "h-10 w-10 rounded-full object-cover",
                    creatorLiveRing ? "ring-2 ring-red-500" : "ring-2 ring-white/80"
                  )}
                />
              ) : (
                <div className="flex h-10 w-10 items-center justify-center rounded-full brand-gradient text-sm font-bold">
                  {(name || "U")[0]?.toUpperCase()}
                </div>
              )}
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  {creatorId ? (
                    <Link href={`/profile/${creatorId}`} className="truncate text-sm font-bold hover:underline">
                      {handle || "@user"}
                    </Link>
                  ) : (
                    <span className="truncate text-sm font-bold">{handle || "@user"}</span>
                  )}
                  {creatorId && creatorId !== me?.id ? (
                    <FollowChip userId={creatorId} initial={Boolean(item.isFollowing)} />
                  ) : null}
                </div>
                {item.caption ? (
                  <p className="mt-1 line-clamp-2 text-[13px] leading-snug text-white/90">{item.caption}</p>
                ) : null}
              </div>
            </div>
          </div>

          <div className="absolute right-1.5 top-[46%] z-30 flex -translate-y-1/2 flex-col items-center gap-3 md:right-3">
            <button
              type="button"
              onClick={() => goTo(index - 1)}
              disabled={index <= 0}
              className="disabled:opacity-25"
              aria-label="Previous post"
            >
              <MediaOverlayIcon size="sm" className="text-white transition hover:bg-black/55">
                <ChevronUp className="h-4 w-4" />
              </MediaOverlayIcon>
            </button>

            <ActionRail
              item={item}
              commentsOpen={commentsOpen}
              onToggleComments={() => setCommentsOpen((v) => !v)}
              onShare={async () => {
                const url = `${window.location.origin}/media/${item.id}`;
                try {
                  await navigator.clipboard.writeText(url);
                  setShareHint("Link copied");
                } catch {
                  setShareHint("Copy failed");
                }
                window.setTimeout(() => setShareHint(""), 1600);
              }}
              shareHint={shareHint}
              isOwner={isOwner}
              locked={locked}
              onDelete={() => {
                setDeleteError("");
                setDeleteOpen(true);
              }}
            />

            <button
              type="button"
              onClick={() => goTo(index + 1)}
              disabled={index >= items.length - 1}
              className="disabled:opacity-25"
              aria-label="Next post"
            >
              <MediaOverlayIcon size="sm" className="text-white transition hover:bg-black/55">
                <ChevronDown className="h-4 w-4" />
              </MediaOverlayIcon>
            </button>
          </div>
        </div>
      </div>

      {commentsOpen ? (
        <CommentsPanel
          item={item}
          onClose={() => setCommentsOpen(false)}
          onCount={(count) => {
            setDetails((prev) => ({
              ...prev,
              [item.id]: { ...(prev[item.id] ?? item), commentCount: count },
            }));
          }}
        />
      ) : null}

      <DeletePostDialog
        open={deleteOpen}
        kind={deleteKind}
        busy={deleting}
        error={deleteError}
        onCancel={() => {
          if (deleting) return;
          setDeleteOpen(false);
          setDeleteError("");
        }}
        onConfirm={confirmDelete}
      />
    </div>
  );
}

function applyFit(el: HTMLVideoElement | HTMLImageElement, width: number, height: number) {
  el.style.objectFit = width > height ? "contain" : "cover";
}

function ZoomableImage({
  src,
  onLoad,
}: {
  src: string;
  onLoad?: (e: React.SyntheticEvent<HTMLImageElement>) => void;
}) {
  const [scale, setScale] = useState(1);
  const pinch = useRef<{ dist: number; scale: number } | null>(null);

  function clamp(next: number) {
    return Math.min(4, Math.max(1, next));
  }

  return (
    <div
      data-media-zoomed={scale > 1 ? "1" : undefined}
      className="absolute inset-0 z-0 overflow-hidden bg-black touch-none"
      onDoubleClick={() => setScale((s) => (s > 1 ? 1 : 2.4))}
      onWheel={(e) => {
        if (Math.abs(e.deltaY) < 2) return;
        e.preventDefault();
        setScale((s) => clamp(s + (e.deltaY < 0 ? 0.18 : -0.18)));
      }}
      onTouchStart={(e) => {
        if (e.touches.length === 2) {
          const a = e.touches[0];
          const b = e.touches[1];
          pinch.current = {
            dist: Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY),
            scale,
          };
        }
      }}
      onTouchMove={(e) => {
        if (e.touches.length !== 2 || !pinch.current) return;
        e.preventDefault();
        e.stopPropagation();
        const a = e.touches[0];
        const b = e.touches[1];
        const dist = Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY);
        setScale(clamp((pinch.current.scale * dist) / pinch.current.dist));
      }}
      onTouchEnd={() => {
        pinch.current = null;
        setScale((s) => (s < 1.08 ? 1 : s));
      }}
      onPointerDown={(e) => {
        if (scale > 1) e.stopPropagation();
      }}
    >
      <img
        src={src}
        alt=""
        className="h-full w-full bg-black object-contain"
        style={{ transform: `scale(${scale})`, transformOrigin: "center center" }}
        onLoad={onLoad}
      />
    </div>
  );
}

function ReelMedia({
  item,
  playback,
  thumb,
}: {
  item: FeedItem;
  playback: string;
  thumb?: string;
}) {
  const file = pickPreferredMediaUrl(item.mediaUrl, item.streamUrl, playback);
  const asVideo = Boolean(file) && !isImageFeedItem(item, file) && !looksLikeImageUrl(file);

  if (!asVideo) {
    const src = originalMediaUrl(playback);
    return (
      <ZoomableImage
        src={src}
        onLoad={(e) => {
          const el = e.currentTarget;
          el.style.objectFit = el.naturalHeight > el.naturalWidth ? "cover" : "contain";
        }}
      />
    );
  }

  return <ReelVideo key={file} src={playbackVideoUrl(file)} poster={thumb} active />;
}

function ReelVideo({
  src,
  poster,
  active,
}: {
  src: string;
  poster?: string;
  active: boolean;
}) {
  const ref = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.muted = false;
    el.defaultMuted = false;
    if (active) {
      const play = el.play();
      if (play) play.catch(() => {});
    } else {
      el.pause();
    }
  }, [active, src]);

  return (
    <video
      ref={ref}
      src={src}
      poster={poster ? cloudinaryUrl(poster, "c_fill,w_720,h_1280") : undefined}
      autoPlay={active}
      playsInline
      loop
      muted={false}
      className="absolute inset-0 z-0 h-full w-full bg-black object-cover"
      onLoadedMetadata={(e) => {
        const el = e.currentTarget;
        applyFit(el, el.videoWidth, el.videoHeight);
        el.muted = false;
        if (active && el.paused) el.play().catch(() => {});
      }}
      onError={(e) => {
        if (e.currentTarget.error?.code === MediaError.MEDIA_ERR_ABORTED) return;
      }}
      onClick={() => {
        const el = ref.current;
        if (!el) return;
        el.muted = false;
        if (el.paused) el.play().catch(() => {});
        else el.pause();
      }}
    />
  );
}

function FollowChip({ userId, initial }: { userId: string; initial: boolean }) {
  const [following, setFollowing] = useState(initial);
  const [busy, setBusy] = useState(false);

  async function toggle() {
    if (busy) return;
    setBusy(true);
    const next = !following;
    setFollowing(next);
    try {
      if (next) await followUser(userId);
      else await unfollowUser(userId);
    } catch {
      setFollowing(!next);
    } finally {
      setBusy(false);
    }
  }

  return (
    <button
      type="button"
      onClick={toggle}
      className={cn(
        "shrink-0 rounded-full px-2.5 py-0.5 text-[11px] font-bold transition",
        following
          ? "border border-white/25 bg-white/10 text-white"
          : "bg-white text-black hover:bg-white/90"
      )}
    >
      {following ? "Following" : "Follow"}
    </button>
  );
}

function ActionRail({
  item,
  commentsOpen,
  onToggleComments,
  onShare,
  shareHint,
  isOwner,
  onDelete,
  locked,
}: {
  item: FeedItem;
  commentsOpen: boolean;
  onToggleComments: () => void;
  onShare: () => void;
  shareHint: string;
  isOwner?: boolean;
  onDelete?: () => void;
  locked?: boolean;
}) {
  const user = useAuthStore((s) => s.user);
  const targetType = mediaTargetType(item.type);
  const [liked, setLiked] = useState(Boolean(item.likedByMe));
  const [likes, setLikes] = useState(item.likeCount ?? 0);
  const [busy, setBusy] = useState(false);
  const [ownerViews, setOwnerViews] = useState<number | null>(null);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (!user?.id) {
      setSaved(false);
      return;
    }
    setSaved(isSavedLocal(user.id, targetType, item.id));
  }, [user?.id, targetType, item.id]);

  useEffect(() => {
    setLiked(Boolean(item.likedByMe));
    setLikes(item.likeCount ?? 0);
    setOwnerViews(null);
    let cancelled = false;
    getLikeSummary(targetType, item.id)
      .then((s) => {
        if (cancelled) return;
        setLiked(s.likedByMe);
        if (s.count) setLikes(s.count);
      })
      .catch(() => {});
    if (isOwner) {
      getOwnerInsightsViews(item)
        .then((views) => {
          if (!cancelled) setOwnerViews(views);
        })
        .catch(() => {
          if (!cancelled) setOwnerViews(null);
        });
    }
    return () => {
      cancelled = true;
    };
  }, [isOwner, item.id, item.type, item.likeCount, item.likedByMe, targetType]);

  async function toggleLike() {
    if (busy) return;
    setBusy(true);
    const next = !liked;
    setLiked(next);
    setLikes((n) => Math.max(0, n + (next ? 1 : -1)));
    try {
      if (next) await likeMedia(targetType, item.id);
      else await unlikeMedia(targetType, item.id);
    } catch {
      setLiked(!next);
      setLikes((n) => Math.max(0, n + (next ? -1 : 1)));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col items-center gap-3.5">
      <button type="button" onClick={toggleLike} className="flex flex-col items-center gap-0.5">
        <MediaOverlayIcon className={cn("transition hover:bg-black/55", liked && "bg-red-500/25")}>
          <Heart className={cn("h-5 w-5", liked ? "fill-red-500 text-red-500" : "text-white")} />
        </MediaOverlayIcon>
        <span className="text-[11px] font-semibold tabular-nums">{formatCount(likes)}</span>
      </button>
      <button type="button" onClick={onToggleComments} className="flex flex-col items-center gap-0.5">
        <MediaOverlayIcon className={cn("transition hover:bg-black/55", commentsOpen && "bg-brand-purple/35")}>
          <MessageCircle className="h-5 w-5 text-white" />
        </MediaOverlayIcon>
        <span className="text-[11px] font-semibold tabular-nums">{formatCount(item.commentCount ?? 0)}</span>
      </button>
      {isOwner && ownerViews !== null ? (
        <div className="flex flex-col items-center gap-0.5">
          <MediaOverlayIcon>
            <Eye className="h-5 w-5 text-white" />
          </MediaOverlayIcon>
          <span className="text-[11px] font-semibold tabular-nums">{formatCount(ownerViews)}</span>
        </div>
      ) : null}
      <button type="button" onClick={onShare} className="flex flex-col items-center gap-0.5" aria-label="Share">
        <MediaOverlayIcon className="transition hover:bg-black/55">
          <Share2 className="h-5 w-5 text-white" />
        </MediaOverlayIcon>
        {shareHint ? <span className="text-[10px] font-semibold">{shareHint}</span> : null}
      </button>
      <button
        type="button"
        onClick={async () => {
          if (!user?.id || locked) return;
          const next = await toggleSavedMedia(user.id, targetType, item.id, !locked);
          setSaved(next);
        }}
        className="flex flex-col items-center gap-0.5"
        aria-label={saved ? "Unsave" : "Save"}
        disabled={Boolean(locked) || !user?.id}
      >
        <MediaOverlayIcon className={cn("transition hover:bg-black/55", saved && "bg-brand-purple/35")}>
          <Bookmark className={cn("h-5 w-5 text-white", saved && "fill-white")} />
        </MediaOverlayIcon>
      </button>
      {isOwner && onDelete ? (
        <button type="button" onClick={onDelete} className="flex flex-col items-center" aria-label="Delete">
          <MediaOverlayIcon className="bg-red-600/90 transition hover:bg-red-500">
            <Trash2 className="h-5 w-5 text-white" />
          </MediaOverlayIcon>
        </button>
      ) : null}
    </div>
  );
}

function groupedReactions(comments: MediaComment[], parentId: string, myId?: string) {
  const map = new Map<string, { code: string; count: number; mineId?: string }>();
  for (const c of comments) {
    const parsed = parseReaction(c.content);
    if (!parsed) continue;
    const target = parsed.parentId || c.parentId;
    if (target !== parentId) continue;
    const cur = map.get(parsed.code) || { code: parsed.code, count: 0 };
    cur.count += 1;
    if (myId && c.authorId === myId) cur.mineId = c.id;
    map.set(parsed.code, cur);
  }
  return Array.from(map.values());
}

function CommentsPanel({
  item,
  onClose,
  onCount,
}: {
  item: FeedItem;
  onClose: () => void;
  onCount: (count: number) => void;
}) {
  const me = useAuthStore((s) => s.user);
  const queryClient = useQueryClient();
  const targetType = mediaTargetType(item.type);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [gifOpen, setGifOpen] = useState(false);
  const [pendingGif, setPendingGif] = useState<{ url: string; preview: string } | null>(null);
  const [attachError, setAttachError] = useState("");
  const [reactingTo, setReactingTo] = useState<string | null>(null);
  const [replyTo, setReplyTo] = useState<{ id: string; name?: string } | null>(null);
  const [menuFor, setMenuFor] = useState<string | null>(null);
  const [replyShown, setReplyShown] = useState<Record<string, number>>({});
  const listRef = useRef<HTMLDivElement>(null);
  const pressTimer = useRef<number>(0);

  const query = useQuery({
    queryKey: ["media-comments", targetType, item.id],
    queryFn: () => listAllComments(targetType, item.id),
    refetchInterval: 3000,
    refetchIntervalInBackground: false,
  });

  const comments = query.data?.comments ?? [];
  const visible = comments.filter((c) => !isReactionComment(c.content));
  const byId = new Map(visible.map((c) => [c.id, c]));
  const rootIdFor = (comment: MediaComment) => {
    let current = comment;
    const seen = new Set<string>();
    while (current.parentId && byId.has(current.parentId) && !seen.has(current.id)) {
      seen.add(current.id);
      const parent = byId.get(current.parentId);
      if (!parent) break;
      current = parent;
    }
    return current.id;
  };
  const byNewest = (a: MediaComment, b: MediaComment) =>
    new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime();
  const topLevel = visible
    .filter((c) => !c.parentId || !byId.has(c.parentId))
    .slice()
    .sort(byNewest);
  const repliesFor = (id: string) =>
    visible
      .filter((c) => c.id !== id && rootIdFor(c) === id)
      .sort(byNewest);

  useEffect(() => {
    if (!query.data) return;
    rememberCommentCount(targetType, item.id, visible.length);
    onCount(visible.length);
  }, [item.id, onCount, query.data, targetType, visible.length]);

  useEffect(() => {
    const refetch = () => {
      queryClient.invalidateQueries({ queryKey: ["media-comments", targetType, item.id] });
    };
    const unsub = onSocketEvent("comment_created", refetch);
    const unsub2 = onSocketEvent("new_comment", refetch);
    return () => {
      unsub();
      unsub2();
    };
  }, [item.id, queryClient, targetType]);

  async function submit() {
    const text = draft.trim();
    const gifUrl = pendingGif?.url;
    if ((!text && !gifUrl) || sending) return;
    setSending(true);
    setAttachError("");
    const parentId = replyTo?.id;
    const parentName = replyTo?.name;
    const gif = pendingGif;
    setDraft("");
    setPendingGif(null);
    setGifOpen(false);
    setReplyTo(null);
    try {
      const content = composeCommentContent(text, gifUrl);
      if (!content) return;
      await createComment(targetType, item.id, content, parentId);
      await query.refetch();
      requestAnimationFrame(() => {
        listRef.current?.scrollTo({ top: 0, behavior: "smooth" });
      });
    } catch (err) {
      setDraft(text);
      if (gif) setPendingGif(gif);
      if (parentId) setReplyTo({ id: parentId, name: parentName });
      setAttachError(err instanceof Error ? err.message : "Could not post this comment.");
    } finally {
      setSending(false);
    }
  }

  async function onCommentAction(c: MediaComment, action: "copy" | "delete") {
    const mine = Boolean(me?.id && c.authorId === me.id);
    setMenuFor(null);
    if (action === "copy") {
      await navigator.clipboard.writeText(textWithoutMedia(c.content) || decodeCommentText(c.content));
      return;
    }
    if (!mine) return;
    await deleteComment(c.id);
    await query.refetch();
  }

  async function toggleReaction(parentId: string, code: string) {
    if (!me || sending) return;
    const mine = groupedReactions(comments, parentId, me.id).find((r) => r.code === code)?.mineId;
    setReactingTo(null);
    try {
      if (mine) await deleteComment(mine);
      else await createComment(targetType, item.id, reactionToken(code, parentId), parentId);
      await query.refetch();
    } catch {
      return;
    }
  }

  function renderComment(c: MediaComment, compact = false) {
    const body = textWithoutMedia(c.content);
    const media = extractMediaUrls(c.content);
    const emojiOnly = body.length > 0 && media.length === 0 && !/[A-Za-z0-9]/.test(body);
    const chips = groupedReactions(comments, c.id, me?.id);
    const mine = Boolean(me?.id && c.authorId === me.id);
    return (
      <div
        key={c.id}
        className={cn("relative flex gap-3", compact && "pl-10")}
        onContextMenu={(e) => {
          e.preventDefault();
          setMenuFor(c.id);
        }}
        onPointerDown={() => {
          window.clearTimeout(pressTimer.current);
          pressTimer.current = window.setTimeout(() => setMenuFor(c.id), 480);
        }}
        onPointerUp={() => window.clearTimeout(pressTimer.current)}
        onPointerCancel={() => window.clearTimeout(pressTimer.current)}
      >
        {c.authorAvatarUrl ? (
          <img
            src={cloudinaryUrl(c.authorAvatarUrl, "c_fill,w_64,h_64,g_face")}
            alt=""
            className={cn("shrink-0 rounded-full object-cover", compact ? "h-7 w-7" : "h-9 w-9")}
          />
        ) : (
          <div
            className={cn(
              "flex shrink-0 items-center justify-center rounded-full bg-white/10 text-xs font-bold",
              compact ? "h-7 w-7" : "h-9 w-9"
            )}
          >
            {(c.authorName || "U")[0]?.toUpperCase()}
          </div>
        )}
        <div className="min-w-0 flex-1">
          <p className="text-[13px] leading-snug">
            <span className="font-bold text-white">{handleLabel(c.authorName)} </span>
            {body ? <span className={cn("text-zinc-200", emojiOnly && "text-2xl leading-none")}>{body}</span> : null}
          </p>
          {media.map((url) => (
            <img
              key={url}
              src={url}
              alt={`${handleLabel(c.authorName)}${body ? ` ${body}` : ""}`}
              className="mt-2 max-h-36 rounded-xl object-cover"
            />
          ))}
          {menuFor === c.id ? (
            <div className="absolute right-0 top-0 z-20 overflow-hidden rounded-xl border border-white/10 bg-[#1c1c22] text-xs shadow-xl">
              <button type="button" className="block w-full px-3 py-2 text-left hover:bg-white/10" onClick={() => onCommentAction(c, "copy")}>
                Copy
              </button>
            </div>
          ) : null}
          <div className="mt-1 flex flex-wrap items-center gap-2 text-[10px] text-zinc-500">
            {c.createdAt ? (
              <span>
                {new Date(c.createdAt).toLocaleString(undefined, {
                  month: "short",
                  day: "numeric",
                  hour: "numeric",
                  minute: "2-digit",
                })}
              </span>
            ) : null}
            <button type="button" className="font-semibold hover:text-white" onClick={() => setReplyTo({ id: c.id, name: c.authorName })}>
              Reply
            </button>
            {me ? (
              <button type="button" className="font-semibold hover:text-white" onClick={() => setReactingTo(reactingTo === c.id ? null : c.id)}>
                React
              </button>
            ) : null}
            {mine ? (
              <button type="button" className="font-semibold text-red-400 hover:text-red-300" onClick={() => onCommentAction(c, "delete")}>
                Delete
              </button>
            ) : null}
          </div>
          {reactingTo === c.id ? (
            <div className="mt-2 flex flex-wrap gap-1">
              {QUICK_REACTION_CODES.map((code) => (
                <button
                  key={code}
                  type="button"
                  className="flex h-8 w-8 items-center justify-center rounded-full bg-white/5 text-base hover:bg-white/10"
                  onClick={() => toggleReaction(c.id, code)}
                >
                  {glyphForCode(code)}
                </button>
              ))}
            </div>
          ) : null}
          {chips.length ? (
            <div className="mt-2 flex flex-wrap gap-1">
              {chips.map((chip) => (
                <button
                  key={chip.code}
                  type="button"
                  onClick={() => toggleReaction(c.id, chip.code)}
                  className={cn(
                    "flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-semibold",
                    chip.mineId
                      ? "border border-brand-purple bg-brand-purple/25 text-white"
                      : "border border-white/10 bg-white/5 text-zinc-300 hover:bg-white/10"
                  )}
                >
                  <span>{glyphForCode(chip.code)}</span>
                  <span>{chip.count}</span>
                </button>
              ))}
            </div>
          ) : null}
        </div>
      </div>
    );
  }

  return (
    <aside
      data-comments-panel
      className="flex h-full w-full shrink-0 flex-col border-l border-white/10 bg-[#121218] max-md:absolute max-md:inset-0 max-md:z-50 md:w-[min(100%,400px)]"
    >
      <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
        <div>
          <h2 className="text-sm font-bold">Comments</h2>
          <p className="text-[11px] text-zinc-400">{formatCount(visible.length)} on this post</p>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="flex h-8 w-8 items-center justify-center rounded-full bg-white/5 text-zinc-300 hover:bg-white/10 hover:text-white"
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      <div ref={listRef} className="flex-1 overflow-y-auto px-4 py-3 space-y-3" onClick={() => setMenuFor(null)}>
        {query.isLoading ? (
          <div className="flex justify-center py-16">
            <Loader2 className="h-6 w-6 animate-spin text-brand-purple" />
          </div>
        ) : topLevel.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <MessageCircle className="h-8 w-8 text-zinc-600" />
            <p className="mt-3 text-sm font-semibold">No comments yet</p>
            <p className="mt-1 text-xs text-zinc-500">Be the first to say something</p>
          </div>
        ) : (
          topLevel.map((c) => {
            const replies = repliesFor(c.id);
            const shown = replyShown[c.id] ?? 5;
            const visibleReplies = replies.slice(0, shown);
            return (
              <div key={c.id} className="space-y-2">
                {renderComment(c)}
                {visibleReplies.map((reply) => renderComment(reply, true))}
                {shown < replies.length ? (
                  <button
                    type="button"
                    className="pl-10 text-[11px] font-semibold text-brand-purple hover:text-white"
                    onClick={() =>
                      setReplyShown((prev) => ({
                        ...prev,
                        [c.id]: (prev[c.id] ?? 5) + 5,
                      }))
                    }
                  >
                    View more replies
                  </button>
                ) : null}
              </div>
            );
          })
        )}
      </div>

      <form
        className="border-t border-white/10 p-3"
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
      >
        {replyTo ? (
          <div className="mb-2 flex items-center justify-between text-[11px] text-zinc-400">
            <span>Replying to {handleLabel(replyTo.name)}</span>
            <button type="button" onClick={() => setReplyTo(null)}>
              Cancel
            </button>
          </div>
        ) : null}
        {pickerOpen ? (
          <div className="mb-2 max-h-36 overflow-y-auto rounded-xl border border-white/10 bg-white/5 p-2">
            <div className="grid grid-cols-8 gap-1">
              {COMMENT_EMOJI_PACK.map((item) => (
                <button
                  key={item.code}
                  type="button"
                  className="flex h-8 w-8 items-center justify-center rounded-lg text-lg hover:bg-white/10"
                  onClick={() => setDraft((prev) => prev + item.glyph)}
                >
                  {item.glyph}
                </button>
              ))}
            </div>
          </div>
        ) : null}
        {gifOpen ? (
          <GifPicker
            onPick={(gif) => {
              setPendingGif({ url: gif.url, preview: gif.previewUrl });
              setGifOpen(false);
              setAttachError("");
            }}
          />
        ) : null}
        {pendingGif ? (
          <div className="mb-2 flex items-center gap-2">
            <img src={pendingGif.preview} alt="" className="h-14 w-14 rounded-lg object-cover" />
            <button
              type="button"
              onClick={() => setPendingGif(null)}
              className="text-[11px] font-semibold text-zinc-400 hover:text-white"
            >
              Remove
            </button>
          </div>
        ) : null}
        {attachError ? <p className="mb-2 text-[11px] text-red-400">{attachError}</p> : null}
        <div className="flex items-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-3 py-2">
          <button
            type="button"
            disabled={!me}
            onClick={() => {
              setPickerOpen((v) => !v);
              setGifOpen(false);
            }}
            className="flex h-8 w-8 items-center justify-center rounded-full text-zinc-400 hover:bg-white/10 hover:text-white disabled:opacity-40"
          >
            <Smile className="h-4 w-4" />
          </button>
          <button
            type="button"
            disabled={!me || sending}
            onClick={() => {
              setGifOpen((v) => !v);
              setPickerOpen(false);
            }}
            className="flex h-8 w-8 items-center justify-center rounded-full text-[10px] font-bold text-zinc-400 hover:bg-white/10 hover:text-white disabled:opacity-40"
            aria-label="Add GIF"
          >
            GIF
          </button>
          <input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder={me ? "Add a comment…" : "Sign in to comment"}
            disabled={!me || sending}
            className="min-w-0 flex-1 bg-transparent text-sm text-white outline-none placeholder:text-zinc-500"
          />
          <button
            type="submit"
            disabled={(!draft.trim() && !pendingGif) || sending || !me}
            className="flex h-8 w-8 items-center justify-center rounded-full brand-gradient text-white disabled:opacity-40"
          >
            {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
          </button>
        </div>
      </form>
    </aside>
  );
}
