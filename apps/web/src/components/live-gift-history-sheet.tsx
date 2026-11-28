"use client";

import { useEffect, useState } from "react";
import { getStreamGifts } from "@/lib/api/streams";
import { enrichGiftRows, parseGiftRows, type GiftRow } from "@/lib/gifts";
import { cloudinaryUrl, cn } from "@/lib/utils";
import { Gift, X } from "lucide-react";

export function LiveGiftHistorySheet({
  streamId,
  open,
  onClose,
}: {
  streamId: string;
  open: boolean;
  onClose: () => void;
}) {
  const [loading, setLoading] = useState(true);
  const [gifts, setGifts] = useState<GiftRow[]>([]);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    setLoading(true);
    getStreamGifts(streamId)
      .then((res) => enrichGiftRows(parseGiftRows(res)))
      .then((rows) => {
        if (!cancelled) setGifts(rows);
      })
      .catch(() => {
        if (!cancelled) setGifts([]);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, streamId]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[80] flex items-end justify-center bg-black/70 p-3 sm:items-center">
      <button type="button" className="absolute inset-0" aria-label="Close" onClick={onClose} />
      <div className="relative z-10 flex max-h-[80vh] w-full max-w-md flex-col overflow-hidden rounded-3xl border border-white/10 bg-[#141420] shadow-2xl">
        <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
          <h2 className="font-sans text-base font-extrabold text-white">Gift history</h2>
          <button
            type="button"
            onClick={onClose}
            className="flex h-9 w-9 items-center justify-center rounded-full bg-white/5 text-white hover:bg-white/10"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto p-2">
          {loading ? (
            <div className="flex justify-center py-12">
              <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
            </div>
          ) : gifts.length === 0 ? (
            <p className="py-12 text-center text-sm text-zinc-400">No gifts yet</p>
          ) : (
            <ul className="space-y-1">
              {gifts.map((g) => (
                <li
                  key={g.id}
                  className={cn("flex items-center gap-3 rounded-2xl px-3 py-2.5 hover:bg-white/5")}
                >
                  {g.iconUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={cloudinaryUrl(g.iconUrl)} alt="" className="h-10 w-10 rounded-full object-cover" />
                  ) : (
                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-amber-400/15 text-amber-300">
                      <Gift className="h-4 w-4" />
                    </div>
                  )}
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-bold text-white">
                      {g.senderName} sent {g.giftName}
                    </p>
                    <p className="truncate text-xs text-zinc-400">
                      {g.quantity > 1 ? `×${g.quantity}` : "Gift"}
                    </p>
                  </div>
                  <span className="text-xs font-semibold text-white/80">x{g.quantity}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}
