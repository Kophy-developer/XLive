"use client";

import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";
import { listTrendingGiphy, searchGiphy, type GiphyGif } from "@/lib/api/giphy";

export function GifPicker({ onPick }: { onPick: (gif: GiphyGif) => void }) {
  const [q, setQ] = useState("");
  const [items, setItems] = useState<GiphyGif[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    const handle = window.setTimeout(async () => {
      setLoading(true);
      setError("");
      try {
        const next = q.trim() ? await searchGiphy(q) : await listTrendingGiphy();
        if (!cancelled) setItems(next);
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : "Could not load GIFs.");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }, q.trim() ? 350 : 0);
    return () => {
      cancelled = true;
      window.clearTimeout(handle);
    };
  }, [q]);

  return (
    <div className="mb-2 overflow-hidden rounded-xl border border-white/10 bg-[#1a1a22]">
      <div className="flex items-center gap-2 border-b border-white/10 px-2 py-2">
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search GIPHY"
          className="min-w-0 flex-1 rounded-lg bg-white/5 px-2 py-1.5 text-xs text-white outline-none placeholder:text-zinc-500"
        />
        <span className="shrink-0 text-[9px] font-bold tracking-wide text-zinc-500">GIPHY</span>
      </div>
      <div className="max-h-44 overflow-y-auto p-2">
        {loading ? (
          <div className="flex justify-center py-8">
            <Loader2 className="h-5 w-5 animate-spin text-brand-purple" />
          </div>
        ) : error ? (
          <p className="px-1 py-4 text-center text-[11px] text-red-400">{error}</p>
        ) : items.length === 0 ? (
          <p className="px-1 py-4 text-center text-[11px] text-zinc-500">No GIFs found</p>
        ) : (
          <div className="grid grid-cols-3 gap-1.5">
            {items.map((gif) => (
              <button
                key={gif.id}
                type="button"
                onClick={() => onPick(gif)}
                className="overflow-hidden rounded-lg bg-white/5"
              >
                <img src={gif.previewUrl} alt={gif.title} className="h-20 w-full object-cover" />
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
