"use client";

import { Loader2, Trash2 } from "lucide-react";

export function DeletePostDialog({
  open,
  kind,
  busy,
  error,
  onCancel,
  onConfirm,
}: {
  open: boolean;
  kind: "post" | "clip";
  busy?: boolean;
  error?: string;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  if (!open) return null;
  const label = kind === "clip" ? "clip" : "post";

  return (
    <div className="fixed inset-0 z-[140] flex items-center justify-center bg-black/70 p-4 backdrop-blur-md">
      <div className="w-full max-w-sm overflow-hidden rounded-3xl border border-white/10 bg-[#14141c] shadow-2xl shadow-black/50">
        <div className="px-6 pt-6 pb-4">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-red-500/15 text-red-400">
            <Trash2 className="h-5 w-5" />
          </div>
          <h2 className="mt-4 text-lg font-bold text-white">Delete {label}?</h2>
          <p className="mt-1.5 text-sm text-zinc-400">This cannot be undone.</p>
          {error ? <p className="mt-3 text-sm text-red-400">{error}</p> : null}
        </div>
        <div className="flex gap-2 px-6 pb-6">
          <button
            type="button"
            disabled={busy}
            onClick={onCancel}
            className="flex-1 rounded-full border border-white/15 bg-white/5 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10 disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={onConfirm}
            className="flex flex-1 items-center justify-center gap-2 rounded-full bg-red-600 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-red-500 disabled:opacity-50"
          >
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
            Delete
          </button>
        </div>
      </div>
    </div>
  );
}
