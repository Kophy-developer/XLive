"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { getVideo } from "@/lib/api/misc";
import { useAuthStore } from "@/lib/stores";
import { syncSavedFromApi, type SavedMediaRef } from "@/lib/saved-media";
import { cloudinaryUrl } from "@/lib/utils";

type SavedCard = SavedMediaRef & {
  title?: string;
  thumbnailUrl?: string;
};

export default function SavedMediaPage() {
  const user = useAuthStore((s) => s.user);
  const [items, setItems] = useState<SavedCard[]>([]);
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
      const cards: SavedCard[] = [];
      for (const ref of refs) {
        try {
          const detail = await getVideo(ref.targetId);
          const access = (detail as { access?: { allowed?: boolean; needsPurchase?: boolean } }).access;
          const locked = access?.allowed === false || access?.needsPurchase === true;
          if (locked) continue;
          cards.push({
            ...ref,
            title: String(
              (detail as { title?: string; caption?: string }).title ||
                (detail as { caption?: string }).caption ||
                ""
            ),
            thumbnailUrl: String(
              (detail as { thumbnailUrl?: string; thumbnail?: string }).thumbnailUrl ||
                (detail as { thumbnail?: string }).thumbnail ||
                ""
            ),
          });
        } catch {
          cards.push(ref);
        }
      }
      setItems(cards);
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
                key={`${item.targetType}:${item.targetId}`}
                href={`/media/${item.targetId}`}
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
              </Link>
            ))}
          </div>
        )}
      </div>
    </AuthGuard>
  );
}
