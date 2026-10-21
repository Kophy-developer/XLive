"use client";

import { FileText, X } from "lucide-react";
import type { ChatUploadProgress, PendingChatFile } from "@/lib/chat-media";

export function ChatPendingBar({
  items,
  onCaption,
  onRemove,
  disabled,
}: {
  items: PendingChatFile[];
  onCaption: (key: string, caption: string) => void;
  onRemove: (key: string) => void;
  disabled?: boolean;
}) {
  if (!items.length) return null;
  return (
    <div className="border-t border-white/10 bg-[#161626]/95 px-3 py-2">
      <div className="flex gap-2 overflow-x-auto pb-1">
        {items.map((item) => (
          <div
            key={item.key}
            className="relative w-36 shrink-0 overflow-hidden rounded-2xl border border-white/10 bg-black/30"
          >
            <button
              type="button"
              disabled={disabled}
              onClick={() => onRemove(item.key)}
              className="absolute right-1.5 top-1.5 z-10 flex h-6 w-6 items-center justify-center rounded-full bg-black/70 text-white"
            >
              <X className="h-3.5 w-3.5" />
            </button>
            {item.mediaType === "image" && item.previewUrl ? (
              <img src={item.previewUrl} alt="" className="h-24 w-full object-cover" />
            ) : item.mediaType === "video" ? (
              <div className="flex h-24 items-center justify-center px-2 text-center text-[11px] font-semibold text-zinc-200">
                {item.file.name}
              </div>
            ) : (
              <div className="flex h-24 items-center gap-2 px-3">
                <FileText className="h-5 w-5 shrink-0 text-white/80" />
                <p className="truncate text-[11px] font-semibold text-white">{item.file.name}</p>
              </div>
            )}
            {item.mediaType === "image" || item.mediaType === "video" ? (
              <input
                value={item.caption}
                disabled={disabled}
                onChange={(e) => onCaption(item.key, e.target.value)}
                placeholder="Caption"
                className="w-full border-t border-white/10 bg-transparent px-2 py-1.5 text-[11px] text-white outline-none placeholder:text-zinc-500"
              />
            ) : (
              <p className="truncate px-2 py-1.5 text-[10px] text-zinc-400">Document</p>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

export function ChatUploadOverlay({ progress }: { progress: ChatUploadProgress | null }) {
  if (!progress) return null;
  return (
    <div className="mx-4 mb-2 rounded-2xl border border-brand-purple/30 bg-[#161626]/95 px-4 py-3">
      <div className="mb-1.5 flex items-center justify-between gap-3 text-[11px] font-semibold text-zinc-200">
        <span className="truncate">
          Uploading {progress.name} ({progress.index}/{progress.total})
        </span>
        <span>{progress.pct}%</span>
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
        <div
          className="h-full rounded-full brand-gradient transition-all duration-200"
          style={{ width: `${Math.max(8, progress.pct)}%` }}
        />
      </div>
    </div>
  );
}
