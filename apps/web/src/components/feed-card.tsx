"use client";

import Link from "next/link";
import { useEffect, useRef, useMemo, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import type { FeedItem } from "@/lib/types";
import { cn, cloudinaryUrl, formatCount, publicHandle, handleLabel, isOwnFeedItem } from "@/lib/utils";
import { albumSlidesOf, coalesceFeedAlbums, displayFeedCaption } from "@/lib/feed-album";
import { Heart, MessageCircle, Radio, Play, Lock, Loader2, Sparkles, Trash2 } from "lucide-react";
import { useAuthStore, useFeedViewerStore } from "@/lib/stores";
import { deleteOwnedMedia } from "@/lib/api/misc";
import { isFeedItemGone, keepVisibleFeedItems, markFeedItemGone, subscribeGoneMedia } from "@/lib/media-gone";
import { AccountChip } from "@/components/account-chip";
import { DeletePostDialog } from "@/components/delete-post-dialog";
import { isCreatorLiveNow } from "@/lib/live-now";
import { isUnlockedLocal } from "@/lib/unlocked-media";

export function FeedCard({
  item,
  playlist,
  loadMoreItems,
  allowOwnerDelete = false,
  hideCreator = false,
  variant = "default",
}: {
  item: FeedItem;
  playlist?: FeedItem[];
  loadMoreItems?: () => Promise<FeedItem[]>;
  allowOwnerDelete?: boolean;
  hideCreator?: boolean;
  variant?: "default" | "profile";
}) {
  const me = useAuthStore((s) => s.user);
  const queryClient = useQueryClient();
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState("");
  const gone = isFeedItemGone(item.id);
  const isStream = item.type === "live" || item.isLive;
  const href = isStream
    ? `/live/${item.streamId ?? item.id}`
    : `/media/${item.id}`;
  const canDelete = allowOwnerDelete && !isStream && isOwnFeedItem(item, me?.id);
  const deleteKind = item.type === "clip" ? "clip" : "post";

  const thumb = item.thumbnailUrl || item.previewUrl;
  const creatorDisplay = publicHandle(item.creator) || publicHandle(item.creatorName);
  const avatar = item.creator?.avatarUrl ?? item.creatorAvatarUrl;
  const isProfile = variant === "profile";
  const showCreator = Boolean(creatorDisplay) && !hideCreator;
  const caption = displayFeedCaption(item);
  const slides = albumSlidesOf(item);
  const isAlbum = slides.length > 1;
  const creatorId = item.creatorId || item.creator?.id;
  const creatorLiveRing = Boolean(creatorId && (isStream || isCreatorLiveNow(creatorId)));

  function handleOpen() {
    if (isStream) return;
    const source = (playlist && playlist.length ? playlist : [item]).filter(
      (i) => i.type !== "live" && !i.isLive && !isFeedItemGone(i.id)
    );
    const list = source.length ? source : [item];
    const idx = Math.max(0, list.findIndex((i) => i.id === item.id));
    useFeedViewerStore.getState().open(list, idx, loadMoreItems);
  }

  async function confirmDelete() {
    if (deleting) return;
    setDeleting(true);
    setDeleteError("");
    try {
      const targets = slides.length ? slides : [item];
      for (const target of targets) {
        await deleteOwnedMedia(target);
        markFeedItemGone(target.id, queryClient);
      }
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["feed"] }),
        queryClient.invalidateQueries({ queryKey: ["explore-feed"] }),
        queryClient.invalidateQueries({ queryKey: ["user-content"] }),
      ]);
      setDeleteOpen(false);
    } catch (err) {
      setDeleteError((err as Error).message || "Could not delete this post.");
    } finally {
      setDeleting(false);
    }
  }

  if (gone) return null;

  return (
    <>
    <Link
      href={href}
      onClick={handleOpen}
      className={cn(
        "group relative flex flex-col overflow-hidden border border-border/80 bg-surface/90 transition duration-200 hover:-translate-y-1 hover:border-brand-purple/40 hover:shadow-xl hover:shadow-brand-purple/15",
        isProfile
          ? "rounded-3xl shadow-lg shadow-black/30"
          : "rounded-2xl shadow-sm"
      )}
    >
      <div
        className={cn(
          "relative w-full overflow-hidden bg-surface-hover/80",
          isProfile ? "aspect-[2/3]" : "aspect-[4/5]"
        )}
      >
        {thumb ? (
          <img
            src={cloudinaryUrl(
              thumb,
              isProfile ? "c_fill,w_800,h_1200,g_auto,q_auto:good" : "c_fill,w_500,h_650,g_auto"
            )}
            alt=""
            loading="lazy"
            className="h-full w-full object-cover transition duration-300 group-hover:scale-105"
            onError={(e) => {
              (e.currentTarget as HTMLElement).style.display = "none";
            }}
          />
        ) : (
          <div className="flex h-full w-full flex-col items-center justify-center gap-2 bg-gradient-to-br from-brand-purple/15 to-brand-sky/10 text-muted">
            <Play className={cn("opacity-40", isProfile ? "h-12 w-12" : "h-8 w-8")} />
            <span className="text-xs font-medium opacity-60">XLive</span>
          </div>
        )}

        <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-transparent" />
        {isProfile ? (
          <div className="pointer-events-none absolute inset-0 flex items-center justify-center opacity-0 transition duration-200 group-hover:opacity-100">
            <span className="flex h-14 w-14 items-center justify-center rounded-full bg-black/50 text-white shadow-lg backdrop-blur-sm">
              <Play className="h-7 w-7 fill-white" />
            </span>
          </div>
        ) : null}

        <div className="absolute left-2.5 top-2.5 flex items-center gap-1.5">
          {isStream ? (
            <span className="flex items-center gap-1 rounded-full bg-red-600/95 px-2.5 py-0.5 text-[11px] font-bold text-white shadow-md">
              <Radio className="h-3 w-3 animate-pulse" /> LIVE
            </span>
          ) : item.type === "clip" ? (
            <span className="flex items-center gap-1 rounded-full bg-brand-purple/90 px-2 py-0.5 text-[10px] font-semibold text-white shadow-md backdrop-blur-sm">
              CLIP
            </span>
          ) : null}

          {!isUnlockedLocal(me?.id, item.id) && (item.needsPurchase || (item.price && item.price > 0)) ? (
            <span className="flex items-center gap-1 rounded-full bg-amber-500/90 px-2 py-0.5 text-[10px] font-bold text-black shadow-md backdrop-blur-sm">
              <Lock className="h-2.5 w-2.5" /> {item.price ?? ""} coins
            </span>
          ) : null}
        </div>

        {canDelete ? (
          <button
            type="button"
            aria-label="Delete post"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              setDeleteError("");
              setDeleteOpen(true);
            }}
            className="absolute right-2.5 top-2.5 z-10 flex h-8 w-8 items-center justify-center rounded-full bg-red-600 text-white shadow-lg shadow-red-600/40 transition hover:bg-red-500"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        ) : null}

        {isAlbum ? (
          <div className="pointer-events-none absolute inset-x-0 bottom-14 z-[1] flex justify-center gap-1">
            {slides.map((slide, i) => (
              <span
                key={slide.id || i}
                className={cn("h-1.5 w-1.5 rounded-full", i === 0 ? "bg-white" : "bg-white/45")}
              />
            ))}
          </div>
        ) : null}

        <div
          className={cn(
            "absolute inset-x-0 bottom-0 flex flex-col gap-2 text-white",
            isProfile ? "px-3.5 pb-3.5 pt-10" : "inset-x-2.5 bottom-2.5 px-0 pb-0 pt-0"
          )}
        >
          {isProfile ? (
            <p className="line-clamp-2 text-[15px] font-semibold leading-snug drop-shadow-md">
              {caption}
            </p>
          ) : null}
          <div className="flex items-center justify-between text-xs text-white/90">
            <div className="flex items-center gap-3 drop-shadow">
              {item.likeCount !== undefined ? (
                <span className="flex items-center gap-1 font-medium">
                  <Heart className={cn("fill-red-500/80 text-red-500", isProfile ? "h-4 w-4" : "h-3.5 w-3.5")} />{" "}
                  {formatCount(item.likeCount)}
                </span>
              ) : null}
              {item.commentCount !== undefined ? (
                <span className="flex items-center gap-1 font-medium">
                  <MessageCircle className={cn("fill-white/20", isProfile ? "h-4 w-4" : "h-3.5 w-3.5")} />{" "}
                  {formatCount(item.commentCount)}
                </span>
              ) : null}
            </div>
          </div>
          {isProfile && showCreator ? (
            <div className="flex items-center gap-2">
              {avatar ? (
                <img
                  src={cloudinaryUrl(avatar, "c_fill,w_48,h_48,g_face")}
                  alt=""
                  className={cn(
                    "h-6 w-6 rounded-full object-cover",
                    creatorLiveRing ? "ring-2 ring-red-500" : "ring-1 ring-white/30"
                  )}
                />
              ) : (
                <div className="flex h-6 w-6 items-center justify-center rounded-full bg-brand-purple/80 text-[10px] font-bold text-white">
                  {creatorDisplay[0]?.toUpperCase() ?? "U"}
                </div>
              )}
              <span className="truncate text-xs font-medium text-white/85">
                {handleLabel(creatorDisplay)}
              </span>
            </div>
          ) : null}
        </div>
      </div>

      {!isProfile ? (
        <div className="hidden flex-1 flex-col justify-between p-3 md:flex">
          <p className="line-clamp-2 text-sm font-semibold leading-snug text-foreground">
            {caption}
          </p>

          {showCreator ? (
            <div className="mt-2.5 flex items-center gap-2">
              {avatar ? (
                <img
                  src={cloudinaryUrl(avatar, "c_fill,w_48,h_48,g_face")}
                  alt=""
                  className={cn(
                    "h-5 w-5 rounded-full object-cover",
                    creatorLiveRing ? "ring-2 ring-red-500" : "ring-1 ring-border"
                  )}
                />
              ) : (
                <div className="flex h-5 w-5 items-center justify-center rounded-full bg-brand-purple/20 text-[10px] font-bold text-brand-purple">
                  {creatorDisplay[0]?.toUpperCase() ?? "U"}
                </div>
              )}
              <span className="truncate text-xs font-medium text-muted">
                {handleLabel(creatorDisplay)}
              </span>
            </div>
          ) : null}
        </div>
      ) : null}
    </Link>
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
    </>
  );
}

export function FeedGrid({
  items,
  empty,
  hasMore = false,
  isFetchingNextPage = false,
  onLoadMore,
  loadMoreItems,
  allowOwnerDelete = false,
  hideCreator = false,
  variant = "default",
}: {
  items: FeedItem[];
  empty?: string;
  hasMore?: boolean;
  isFetchingNextPage?: boolean;
  onLoadMore?: () => void;
  loadMoreItems?: () => Promise<FeedItem[]>;
  allowOwnerDelete?: boolean;
  hideCreator?: boolean;
  variant?: "default" | "profile";
}) {
  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const [goneTick, setGoneTick] = useState(0);

  useEffect(() => subscribeGoneMedia(() => setGoneTick((n) => n + 1)), []);

  const uniqueItems = useMemo(() => {
    const seen = new Set<string>();
    const list: FeedItem[] = [];
    for (const item of coalesceFeedAlbums(keepVisibleFeedItems(items))) {
      if (seen.has(item.id)) continue;
      seen.add(item.id);
      list.push(item);
    }
    return list;
  }, [items, goneTick]);

  useEffect(() => {
    if (!hasMore || isFetchingNextPage || !onLoadMore) return;
    const target = sentinelRef.current;
    if (!target) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) {
          onLoadMore();
        }
      },
      {
        root: null,
        rootMargin: "500px",
        threshold: 0.1,
      }
    );

    observer.observe(target);
    return () => observer.disconnect();
  }, [hasMore, isFetchingNextPage, onLoadMore]);

  useEffect(() => {
    if (!hasMore || isFetchingNextPage || !onLoadMore) return;
    function handleScroll() {
      if (!hasMore || isFetchingNextPage) return;
      const scrollY = window.scrollY || document.documentElement.scrollTop;
      const windowHeight = window.innerHeight;
      const docHeight = document.documentElement.scrollHeight;
      if (scrollY + windowHeight >= docHeight - 650) {
        onLoadMore?.();
      }
    }
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, [hasMore, isFetchingNextPage, onLoadMore]);

  if (!uniqueItems.length && !isFetchingNextPage) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-surface-hover/80 text-muted shadow-inner">
          <Play className="h-7 w-7 opacity-50" />
        </div>
        <p className="mt-4 font-display text-base font-semibold">{empty ?? "Nothing here yet"}</p>
        <p className="mt-1 text-xs text-muted">Check back later or follow more creators</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col">
      <div
        className={cn(
          "grid",
          variant === "profile"
            ? "grid-cols-3 gap-1 sm:gap-2 md:grid-cols-3 lg:grid-cols-3 lg:gap-6"
            : "grid-cols-3 gap-1 p-1.5 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 md:gap-3.5 md:p-4"
        )}
      >
        {uniqueItems.map((item) => (
          <FeedCard
            key={item.id}
            item={item}
            playlist={uniqueItems}
            loadMoreItems={loadMoreItems}
            allowOwnerDelete={allowOwnerDelete}
            hideCreator={hideCreator}
            variant={variant}
          />
        ))}

        {isFetchingNextPage && (
          <>
            {[1, 2, 3, 4].map((n) => (
              <div
                key={`skeleton-${n}`}
                className={cn(
                  "relative flex flex-col overflow-hidden border border-white/5 bg-surface/60 shadow-sm animate-pulse",
                  variant === "profile" ? "rounded-3xl" : "rounded-2xl"
                )}
              >
                <div
                  className={cn(
                    "w-full bg-surface-hover/60",
                    variant === "profile" ? "aspect-[2/3]" : "aspect-[4/5]"
                  )}
                />
                {variant !== "profile" ? (
                  <div className="p-3 space-y-2">
                    <div className="h-3 w-3/4 rounded-full bg-white/10" />
                    <div className="h-2.5 w-1/2 rounded-full bg-white/5" />
                  </div>
                ) : null}
              </div>
            ))}
          </>
        )}
      </div>

      {isFetchingNextPage && (
        <div className="flex items-center justify-center py-6">
          <div className="flex items-center gap-2.5 rounded-full border border-border/80 bg-surface/90 px-5 py-2 text-xs font-semibold text-muted backdrop-blur-xl shadow-lg">
            <Loader2 className="h-4 w-4 animate-spin text-brand-purple" />
            <span>Loading more videos…</span>
          </div>
        </div>
      )}

      {hasMore && !isFetchingNextPage && (
        <div ref={sentinelRef} className="h-10 w-full" />
      )}

      {!hasMore && uniqueItems.length > 8 && (
        <div className="flex items-center justify-center gap-1.5 py-8 text-xs font-medium text-zinc-500">
          <Sparkles className="h-3.5 w-3.5 text-brand-purple/70" />
          <span>You&apos;re all caught up</span>
        </div>
      )}
    </div>
  );
}

export function TabBar({
  tabs,
  active,
  onChange,
}: {
  tabs: { id: string; label: string }[];
  active: string;
  onChange: (id: string) => void;
}) {
  return (
    <div className="flex items-center gap-2 border-b border-border/80 bg-surface/40 px-4 backdrop-blur-md">
      <div className="flex min-w-0 flex-1 gap-1 overflow-x-auto">
        {tabs.map((tab) => {
          const isActive = active === tab.id;
          return (
            <button
              key={tab.id}
              type="button"
              onClick={() => onChange(tab.id)}
              className={cn(
                "relative shrink-0 px-4 py-3 font-display text-sm font-semibold transition duration-150",
                isActive
                  ? "text-foreground"
                  : "text-muted hover:text-foreground"
              )}
            >
              {tab.label}
              {isActive ? (
                <span className="absolute inset-x-3 bottom-0 h-0.5 rounded-full brand-gradient" />
              ) : null}
            </button>
          );
        })}
      </div>
      <AccountChip className="hidden shrink-0 md:flex" />
    </div>
  );
}
