"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { AuthGuard, PageHeader } from "@/components/auth-guard";
import { getVideo } from "@/lib/api/misc";
import { useAuthStore } from "@/lib/stores";
import { listSavedLocal, syncSavedFromSettings, type SavedMediaRef } from "@/lib/saved-media";
import { cloudinaryUrl } from "@/lib/utils";

type SavedCard = SavedMediaRef & {
  title?: string;
  thumbnailUrl?: string;
};

export default function SavedMediaPage() {
  const user = useAuthStore((s) => s.user);
  const [items, setItems] = useState<SavedCard[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!user?.id) {
        setItems([]);
        setLoading(false);
        return;
      }
      setLoading(true);
      const refs = await syncSavedFromSettings(user.id).catch(() => listSavedLocal(user.id));
      const cards: SavedCard[] = [];
      for (const ref of refs) {
        try {
          const detail = await getVideo(ref.targetId);
          const access = (detail as { access?: { allowed?: boolean; needsPurchase?: boolean } }).access;
          const locked = access?.allowed === false || access?.needsPurchase === true;
          if (locked) continue;
          cards.push({
            ...ref,
            title: String((detail as { title?: string; caption?: string }).title || (detail as { caption?: string }).caption || ""),
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
      if (!cancelled) {
        setItems(cards);
        setLoading(false);
      }
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [user?.id]);

  return (
    <AuthGuard>
      <PageHeader title="Saved" backHref="/profile/settings" />
      <div className="mx-auto max-w-3xl px-4 py-6 pb-24">
        {loading ? (
          <div className="flex justify-center py-16">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        ) : items.length === 0 ? (
          <p className="text-center text-sm text-zinc-400 py-16">No saved media yet</p>
        ) : (
          <div className="grid grid-cols-3 gap-1">
            {items.map((item) => (
              <Link
                key={`${item.targetType}:${item.targetId}`}
                href={`/media/${item.targetId}`}
                className="relative aspect-[3/4] overflow-hidden bg-zinc-900"
              >
                {item.thumbnailUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={cloudinaryUrl(item.thumbnailUrl)}
                    alt={item.title || "Saved"}
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <div className="flex h-full items-center justify-center text-zinc-600 text-xs">Media</div>
                )}
              </Link>
            ))}
          </div>
        )}
      </div>
    </AuthGuard>
  );
}
