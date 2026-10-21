"use client";

import { useQuery } from "@tanstack/react-query";
import { Gift, X } from "lucide-react";
import { getGiftCatalog, sendGift } from "@/lib/api/misc";
import { useState } from "react";

export function LiveGiftSheet({
  streamId,
  open,
  onClose,
}: {
  streamId: string;
  open: boolean;
  onClose: () => void;
}) {
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const catalogQuery = useQuery({
    queryKey: ["gift-catalog"],
    queryFn: getGiftCatalog,
    enabled: open,
    staleTime: 60_000,
  });
  const gifts = catalogQuery.data ?? [];

  if (!open) return null;

  async function onSend(giftId: string) {
    setBusyId(giftId);
    setError("");
    try {
      await sendGift({ streamId, giftId, quantity: 1 });
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not send gift");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="fixed inset-0 z-[80] flex items-end justify-center bg-black/70 p-3 sm:items-center">
      <div className="w-full max-w-md rounded-3xl border border-white/10 bg-[#121218] p-4 shadow-2xl">
        <div className="mb-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Gift className="h-4 w-4 text-amber-400" />
            <h3 className="font-sans text-sm font-bold text-white">Send a gift</h3>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-white"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
        {error ? <p className="mb-2 text-xs text-red-400">{error}</p> : null}
        {catalogQuery.isLoading ? (
          <p className="py-10 text-center text-xs text-white/50">Loading gifts…</p>
        ) : !gifts.length ? (
          <p className="py-10 text-center text-xs text-white/50">No gifts available right now.</p>
        ) : (
          <div className="grid max-h-72 grid-cols-4 gap-2 overflow-y-auto">
            {gifts.map((g) => (
              <button
                key={g.id}
                type="button"
                disabled={Boolean(busyId)}
                onClick={() => onSend(g.id)}
                className="flex flex-col items-center gap-1 rounded-2xl border border-white/10 bg-white/5 px-1 py-2.5 text-center transition hover:border-amber-400/40 hover:bg-white/10 disabled:opacity-50"
              >
                {g.iconUrl ? (
                  <img src={g.iconUrl} alt="" className="h-10 w-10 rounded-full object-cover" />
                ) : (
                  <Gift className="h-8 w-8 text-amber-400" />
                )}
                <span className="line-clamp-1 w-full text-[10px] font-semibold text-white">{g.name}</span>
                <span className="text-[10px] text-amber-300">{g.price}</span>
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
