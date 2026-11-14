"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { Layers } from "lucide-react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { coalesceFeedAlbums } from "@/lib/feed-album";
import { useAuthStore } from "@/lib/stores";
import { syncSavedFromApi, type SavedMediaRef } from "@/lib/saved-media";
import type { FeedItem } from "@/lib/types";
import { cloudinaryUrl } from "@/lib/utils";

type SavedTile = {
  id: string;
  title?: string;
  thumbnailUrl?: string;
  isAlbum: boolean;
};

function toFeedItem(ref: SavedMediaRef): FeedItem {
  const mediaType =
    ref.mediaType === "image" || ref.mediaType === "video" ? ref.mediaType : undefined;
  const text = ref.title;
  return {
    id: ref.targetId,
    type: "post",
    title: text,
    caption: text,
    thumbnailUrl: ref.thumbnailUrl,
    mediaType,
  };
}

function toTiles(refs: SavedMediaRef[]): SavedTile[] {
  const coalesced = coalesceFeedAlbums(refs.map(toFeedItem));
  return coalesced.map((item) => ({
    id: item.id,
    title: item.title || item.caption,
    thumbnailUrl: item.thumbnailUrl,
    isAlbum: Boolean(item.albumSlides && item.albumSlides.length > 1),
  }));
}

export default function SavedMediaPage() {
  const user = useAuthStore((s) => s.user);
  const [items, setItems] = useState<SavedTile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [retryTick, setRetryTick] = useState(0);

  const load = useCallback(async () => {
    if (!user?.id) {
      setItems([]);
      setError("");
      setLoading(false);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const refs = await syncSavedFromApi(user.id);
      setItems(toTiles(refs.filter((item) => !item.locked)));
    } catch (err) {
      setItems([]);
      setError((err as Error)?.message || "Could not load saved media. Check your connection and retry.");
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  useEffect(() => {
    void load();
  }, [load, retryTick]);

  return (
    <AuthGuard>
      <PageHeader title="Saved" backHref="/profile/settings" />
      <div className="mx-auto max-w-3xl px-4 py-6 pb-24">
        {loading ? (
          <div className="flex justify-center py-16">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        ) : error ? (
          <div className="flex flex-col items-center gap-3 py-16 text-center">
            <p className="max-w-sm text-sm text-zinc-300">{error}</p>
            <button
              type="button"
              onClick={() => setRetryTick((n) => n + 1)}
              className="rounded-xl brand-gradient px-4 py-2 text-xs font-bold text-white"
            >
              Retry
            </button>
          </div>
        ) : items.length === 0 ? (
          <p className="py-16 text-center text-sm text-zinc-400">No saved media yet</p>
        ) : (
          <div className="grid grid-cols-3 gap-1">
            {items.map((item) => (
              <Link
                key={item.id}
                href={`/media/${item.id}`}
                className="relative aspect-[3/4] overflow-hidden bg-zinc-900"
              >
                {item.thumbnailUrl ? (
                  <img
                    src={cloudinaryUrl(item.thumbnailUrl)}
                    alt={item.title || "Saved"}
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <div className="flex h-full items-center justify-center text-xs text-zinc-600">Media</div>
                )}
                {item.isAlbum ? (
                  <Layers className="absolute right-1.5 top-1.5 h-3.5 w-3.5 text-white drop-shadow" />
                ) : null}
              </Link>
            ))}
          </div>
        )}
      </div>
    </AuthGuard>
  );
}
