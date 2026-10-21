"use client";

import { Download, FileText, Maximize2, MessageSquare, Minimize2, Paperclip, Send, X } from "lucide-react";
import { useEffect, useRef } from "react";
import { cn } from "@/lib/utils";

export type LiveChatMessage = {
  content: string;
  userId?: string;
  userName?: string;
  mediaUrl?: string;
  mediaType?: string;
  fileName?: string;
};

function isImageMessage(m: LiveChatMessage) {
  const t = (m.mediaType || "").toLowerCase();
  if (t.includes("image") || t.includes("photo")) return true;
  return Boolean(m.mediaUrl && /\.(jpg|jpeg|png|webp|gif|heic)(\?|$)/i.test(m.mediaUrl));
}

export function LiveChatPanel({
  title = "Live chat",
  messages,
  chatInput,
  onChatInput,
  onSend,
  onAttach,
  uploading,
  expanded,
  onToggleExpand,
  onClose,
  overlay,
}: {
  title?: string;
  messages: LiveChatMessage[];
  chatInput: string;
  onChatInput: (value: string) => void;
  onSend: () => void;
  onAttach?: () => void;
  uploading?: boolean;
  expanded?: boolean;
  onToggleExpand?: () => void;
  onClose?: () => void;
  overlay?: boolean;
}) {
  const scroller = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = scroller.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }, [messages.length]);

  return (
    <div
      className={cn(
        "flex h-full min-h-0 flex-col bg-[#0f0f0f] text-white",
        overlay && "rounded-t-3xl border-t border-white/10 shadow-2xl lg:rounded-none lg:border-t-0 lg:border-l"
      )}
    >
      <div className="flex items-center justify-between border-b border-white/10 px-3 py-2.5">
        <p className="font-sans text-sm font-semibold text-white">{title}</p>
        <div className="flex items-center gap-1">
          {onToggleExpand ? (
            <button
              type="button"
              onClick={onToggleExpand}
              className="flex h-8 w-8 items-center justify-center rounded-full text-white/80 transition hover:bg-white/10"
              title={expanded ? "Dock chat" : "Expand chat"}
            >
              {expanded ? <Minimize2 className="h-4 w-4" /> : <Maximize2 className="h-4 w-4" />}
            </button>
          ) : null}
          {onClose ? (
            <button
              type="button"
              onClick={onClose}
              className="flex h-8 w-8 items-center justify-center rounded-full text-white/80 transition hover:bg-white/10"
              title="Close chat"
            >
              <X className="h-4 w-4" />
            </button>
          ) : null}
        </div>
      </div>

      <div ref={scroller} className="min-h-0 flex-1 space-y-3 overflow-y-auto px-3 py-3">
        {messages.length === 0 ? (
          <p className="pt-8 text-center text-xs text-white/40">Live chat will appear here…</p>
        ) : (
          messages.map((m, i) => (
            <div key={`${m.userId || "u"}-${i}`} className="flex items-start gap-2">
              <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-white/10 text-[10px] font-bold uppercase">
                {(m.userName || "V").replace(/^@/, "").charAt(0) || "V"}
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-[11px] font-semibold text-white/55">{m.userName || "Viewer"}</p>
                {m.content ? <p className="text-sm leading-snug text-white break-words">{m.content}</p> : null}
                {m.mediaUrl && isImageMessage(m) ? (
                  <a href={m.mediaUrl} target="_blank" rel="noreferrer" className="mt-1.5 block">
                    <img src={m.mediaUrl} alt="" className="max-h-48 max-w-full rounded-xl object-cover" />
                  </a>
                ) : null}
                {m.mediaUrl && !isImageMessage(m) ? (
                  <div className="mt-1.5 flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-2.5 py-2">
                    <FileText className="h-4 w-4 shrink-0 text-white/70" />
                    <span className="min-w-0 flex-1 truncate text-xs text-white/90">{m.fileName || m.content || "Attachment"}</span>
                    <a
                      href={m.mediaUrl}
                      download={m.fileName || true}
                      target="_blank"
                      rel="noreferrer"
                      className="flex h-7 w-7 items-center justify-center rounded-full bg-white/10 text-white"
                    >
                      <Download className="h-3.5 w-3.5" />
                    </a>
                  </div>
                ) : null}
              </div>
            </div>
          ))
        )}
      </div>

      <form
        className="flex items-center gap-1.5 border-t border-white/10 p-2.5"
        onSubmit={(e) => {
          e.preventDefault();
          onSend();
        }}
      >
        {onAttach ? (
          <button
            type="button"
            disabled={uploading}
            onClick={onAttach}
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white/10 text-white disabled:opacity-40"
            title="Attach image or document"
          >
            <Paperclip className="h-4 w-4" />
          </button>
        ) : null}
        <input
          className="h-10 min-w-0 flex-1 rounded-full border border-white/10 bg-white/10 px-3 font-sans text-xs text-white placeholder:text-white/40 outline-none focus:border-brand-purple"
          placeholder="Send a comment…"
          value={chatInput}
          onChange={(e) => onChatInput(e.target.value)}
        />
        <button
          type="submit"
          disabled={uploading || !chatInput.trim()}
          className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full brand-gradient text-white disabled:opacity-40"
        >
          <Send className="h-4 w-4" />
        </button>
      </form>
    </div>
  );
}

export function LiveChatOpenButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex h-11 w-11 items-center justify-center rounded-full border border-white/15 bg-black/70 text-white shadow-lg backdrop-blur-md transition hover:bg-black/85"
      title="Open live chat"
    >
      <MessageSquare className="h-5 w-5" />
    </button>
  );
}
