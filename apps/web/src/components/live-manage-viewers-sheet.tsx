"use client";

import { AudioLines, Mic, MicOff, UserMinus, Users, X } from "lucide-react";
import { cloudinaryUrl, cn } from "@/lib/utils";

export type LiveViewerRow = {
  id: string;
  name: string;
  avatarUrl?: string;
  muted?: boolean;
  talkBack?: boolean;
};

export function LiveManageViewersSheet({
  open,
  onClose,
  viewers,
  talkBackControls,
  busyId,
  onToggleMute,
  onToggleTalkBack,
  onRemove,
}: {
  open: boolean;
  onClose: () => void;
  viewers: LiveViewerRow[];
  talkBackControls: boolean;
  busyId?: string | null;
  onToggleMute: (viewer: LiveViewerRow) => void;
  onToggleTalkBack: (viewer: LiveViewerRow) => void;
  onRemove: (viewerId: string) => void;
}) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[80] flex items-end justify-center bg-black/70 p-3 sm:items-center">
      <button type="button" className="absolute inset-0" aria-label="Close" onClick={onClose} />
      <div className="relative z-10 flex max-h-[85vh] w-full max-w-md flex-col overflow-hidden rounded-3xl border border-white/10 bg-[#141420] shadow-2xl">
        <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
          <div className="flex items-center gap-2">
            <Users className="h-4 w-4 text-brand-purple" />
            <h2 className="font-sans text-base font-extrabold text-white">Manage viewers</h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="flex h-9 w-9 items-center justify-center rounded-full bg-white/5 text-white hover:bg-white/10"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto p-2">
          {viewers.length === 0 ? (
            <p className="py-14 text-center text-sm text-zinc-400">No viewers yet</p>
          ) : (
            <ul className="space-y-1">
              {viewers.map((viewer) => {
                const busy = busyId === viewer.id;
                return (
                  <li
                    key={viewer.id}
                    className="flex items-center gap-3 rounded-2xl px-3 py-2.5 hover:bg-white/5"
                  >
                    {viewer.avatarUrl ? (
                      <img
                        src={cloudinaryUrl(viewer.avatarUrl)}
                        alt=""
                        className="h-10 w-10 rounded-full object-cover"
                      />
                    ) : (
                      <div className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-xs font-bold text-white">
                        {(viewer.name || "?").slice(0, 1).toUpperCase()}
                      </div>
                    )}
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-bold text-white">{viewer.name}</p>
                      {viewer.muted || viewer.talkBack ? (
                        <p className="truncate text-[11px] text-zinc-400">
                          {[viewer.talkBack ? "Talk-back" : null, viewer.muted ? "Muted" : null]
                            .filter(Boolean)
                            .join(" · ")}
                        </p>
                      ) : null}
                    </div>
                    <div className="flex items-center gap-1">
                      {talkBackControls ? (
                        <>
                          <button
                            type="button"
                            disabled={busy || !viewer.talkBack}
                            onClick={() => onToggleMute(viewer)}
                            className={cn(
                              "flex h-9 w-9 items-center justify-center rounded-xl border transition",
                              viewer.talkBack
                                ? "border-white/10 bg-white/10 text-white hover:bg-white/20"
                                : "border-transparent text-zinc-600",
                              busy && "opacity-50"
                            )}
                            aria-label={viewer.muted ? "Unmute" : "Mute"}
                            title={viewer.muted ? "Unmute" : "Mute"}
                          >
                            {viewer.muted ? <MicOff className="h-4 w-4 text-red-400" /> : <Mic className="h-4 w-4" />}
                          </button>
                          <button
                            type="button"
                            disabled={busy}
                            onClick={() => onToggleTalkBack(viewer)}
                            className={cn(
                              "flex h-9 w-9 items-center justify-center rounded-xl border border-white/10 bg-white/10 text-white transition hover:bg-white/20",
                              viewer.talkBack && "border-brand-purple/40 bg-brand-purple/20 text-brand-purple",
                              busy && "opacity-50"
                            )}
                            aria-label={viewer.talkBack ? "End talk-back" : "Enable talk-back"}
                            title={viewer.talkBack ? "End talk-back" : "Enable talk-back"}
                          >
                            <AudioLines className="h-4 w-4" />
                          </button>
                        </>
                      ) : null}
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => onRemove(viewer.id)}
                        className={cn(
                          "flex h-9 w-9 items-center justify-center rounded-xl border border-white/10 bg-white/10 text-white transition hover:bg-red-500/20 hover:text-red-300",
                          busy && "opacity-50"
                        )}
                        aria-label="Remove viewer"
                        title="Remove viewer"
                      >
                        <UserMinus className="h-4 w-4" />
                      </button>
                    </div>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}
