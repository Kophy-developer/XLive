"use client";

import { useState } from "react";
import { Smile, Sparkles, X, Plus } from "lucide-react";
import { cn } from "@/lib/utils";

export const QUICK_EMOJIS = ["❤️", "👍", "😂", "😮", "😢", "🔥", "👏", "🎉"];

export const EMOJI_CATEGORIES: { name: string; icon: string; emojis: string[] }[] = [
  {
    name: "Smileys",
    icon: "😀",
    emojis: [
      "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇", "🥰", "😍", "🤩",
      "😘", "😗", "😚", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐",
      "😑", "😶", "😏", "😒", "🙄", "😬", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢",
      "🤮", "🤧", "🥵", "🥶", "🥴", "😵", "🤯", "🤠", "🥳", "😎", "🤓", "🧐", "😕", "😟", "🙁", "😮",
    ],
  },
  {
    name: "Gestures",
    icon: "👍",
    emojis: [
      "👍", "👎", "👊", "✊", "🤛", "🤜", "🤞", "✌️", "🤟", "🤘", "👌", "🤌", "🤏", "👈", "👉", "👆",
      "👇", "☝️", "✋", "🤚", "🖐️", "🖖", "👋", "🤙", "💪", "🦾", "🖕", "✍️", "🙏", "🤝", "🫶", "👐",
    ],
  },
  {
    name: "Hearts & Fire",
    icon: "❤️",
    emojis: [
      "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❤️‍🔥", "❤️‍🩹", "❣️", "💕", "💞", "💓",
      "💗", "💖", "💘", "💝", "💟", "🔥", "✨", "🌟", "💫", "💥", "💯", "💢", "🎉", "🎊", "🏆", "👑",
    ],
  },
  {
    name: "Animals & Nature",
    icon: "🐶",
    emojis: [
      "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🙈",
      "🙉", "🙊", "🐒", "🐔", "🐧", "🐦", "🐤", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝",
      "🐛", "🦋", "🐌", "🐞", "🐜", "🦟", "🐢", "🐍", "🦎", "🐙", "🦑", "🦐", "🦞", "🦀", "🐡", "🐠",
    ],
  },
  {
    name: "Food & Drinks",
    icon: "🍔",
    emojis: [
      "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥",
      "🥝", "🍅", "🥑", "🥦", "🌽", "🥕", "🍕", "🍔", "🍟", "🌭", "🍿", "🧈", "🥞", "🧇", "🧀", "🍗",
      "🥩", "🌮", "🌯", "🍝", "🍜", "🍣", "🍦", "🍧", "🍨", "🍩", "🍪", "🎂", "🍰", "🧁", "🍫", "🍬",
      "☕", "🍵", "🧃", "🥤", "🧋", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹", "🍾",
    ],
  },
];

export const CHAT_STICKERS = [
  "😂", "😍", "🥳", "😎", "🤩", "😭", "😡", "🥺",
  "👍", "👏", "🙌", "🙏", "💪", "🔥", "💯", "🎉",
  "❤️", "💔", "💜", "⭐", "✨", "💥", "🎁", "👻",
  "🤣", "😘", "🤗", "🤔", "😴", "🤤", "🤯", "🥵",
  "🤡", "💀", "👽", "🤖", "🎃", "😻", "🙈", "👑",
  "✊", "🤝", "🫶", "🤘", "🤙", "👌", "✌️", "🤟",
  "🚀", "💎", "⚡", "🏖️", "🎮", "🍿", "🥂", "🍾",
];

export function QuickReactionsBar({
  onSelectEmoji,
  onOpenPicker,
  alignRight = false,
}: {
  onSelectEmoji: (emoji: string) => void;
  onOpenPicker?: () => void;
  alignRight?: boolean;
}) {
  return (
    <div
      className={cn(
        "absolute -top-10 z-30 flex items-center gap-1 rounded-full border border-white/15 bg-[#141424]/95 p-1 shadow-2xl backdrop-blur-xl animate-in fade-in zoom-in-95 duration-150",
        alignRight ? "right-0" : "left-0"
      )}
    >
      {QUICK_EMOJIS.map((emoji) => (
        <button
          key={emoji}
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            onSelectEmoji(emoji);
          }}
          className="flex h-7 w-7 items-center justify-center rounded-full text-base transition-transform hover:scale-130 active:scale-95"
        >
          {emoji}
        </button>
      ))}

      {onOpenPicker && (
        <button
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            onOpenPicker();
          }}
          className="flex h-7 w-7 items-center justify-center rounded-full text-muted hover:bg-white/10 hover:text-white transition"
          title="More reactions"
        >
          <Plus className="h-3.5 w-3.5" />
        </button>
      )}
    </div>
  );
}

export function ReactionChips({
  reactions,
  currentUserId,
  onToggleReaction,
}: {
  reactions?: { emoji: string; userId?: string; count?: number; userIds?: string[] }[];
  currentUserId?: string;
  onToggleReaction: (emoji: string) => void;
}) {
  if (!reactions || !reactions.length) return null;

  const grouped = new Map<string, { count: number; reacted: boolean }>();

  for (const r of reactions) {
    if (!r.emoji) continue;
    const existing = grouped.get(r.emoji) || { count: 0, reacted: false };
    const userReacted = Boolean(
      (r.userId && currentUserId && r.userId === currentUserId) ||
      (r.userIds && currentUserId && r.userIds.includes(currentUserId))
    );
    const addedCount = typeof r.count === "number" ? r.count : 1;
    grouped.set(r.emoji, {
      count: existing.count + addedCount,
      reacted: existing.reacted || userReacted,
    });
  }

  const list = Array.from(grouped.entries()).filter(([, v]) => v.count > 0);
  if (!list.length) return null;

  return (
    <div className="flex flex-wrap gap-1 px-1 pt-1 pb-0.5">
      {list.map(([emoji, meta]) => (
        <button
          key={emoji}
          type="button"
          onClick={(e) => {
            e.stopPropagation();
            onToggleReaction(emoji);
          }}
          className={cn(
            "flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-semibold backdrop-blur-md transition-all active:scale-95",
            meta.reacted
              ? "border border-brand-purple bg-brand-purple/25 text-white shadow-sm shadow-brand-purple/30"
              : "border border-white/10 bg-white/5 text-zinc-300 hover:bg-white/10"
          )}
        >
          <span>{emoji}</span>
          <span className="text-[10px] tabular-nums text-zinc-300">{meta.count}</span>
        </button>
      ))}
    </div>
  );
}

export function EmojiStickerPicker({
  isOpen,
  onClose,
  onSelectEmoji,
  onSelectSticker,
}: {
  isOpen: boolean;
  onClose: () => void;
  onSelectEmoji: (emoji: string) => void;
  onSelectSticker?: (sticker: string) => void;
}) {
  const [tab, setTab] = useState<"emoji" | "sticker">("emoji");
  const [activeCategory, setActiveCategory] = useState(0);

  if (!isOpen) return null;

  return (
    <div className="absolute bottom-16 left-2 right-2 sm:left-4 sm:right-auto sm:w-96 z-40 rounded-3xl border border-white/15 bg-[#141424]/95 p-3 shadow-2xl backdrop-blur-2xl animate-in fade-in slide-in-from-bottom-3 duration-200">
      <div className="flex items-center justify-between border-b border-white/10 pb-2 px-1">
        <div className="flex gap-1.5">
          <button
            type="button"
            onClick={() => setTab("emoji")}
            className={cn(
              "flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-bold transition",
              tab === "emoji"
                ? "bg-brand-purple text-white shadow-md shadow-brand-purple/30"
                : "text-zinc-400 hover:text-white hover:bg-white/5"
            )}
          >
            <Smile className="h-3.5 w-3.5" />
            <span>Emojis</span>
          </button>
          <button
            type="button"
            onClick={() => setTab("sticker")}
            className={cn(
              "flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-bold transition",
              tab === "sticker"
                ? "bg-brand-purple text-white shadow-md shadow-brand-purple/30"
                : "text-zinc-400 hover:text-white hover:bg-white/5"
            )}
          >
            <Sparkles className="h-3.5 w-3.5" />
            <span>Stickers</span>
          </button>
        </div>

        <button
          type="button"
          onClick={onClose}
          className="rounded-xl p-1.5 text-zinc-400 hover:bg-white/10 hover:text-white transition"
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      {tab === "emoji" ? (
        <div className="mt-2 space-y-2">
          <div className="flex items-center gap-1 overflow-x-auto no-scrollbar border-b border-white/5 pb-1 px-1">
            {EMOJI_CATEGORIES.map((cat, idx) => (
              <button
                key={cat.name}
                type="button"
                onClick={() => setActiveCategory(idx)}
                className={cn(
                  "rounded-lg px-2 py-1 text-sm transition",
                  activeCategory === idx
                    ? "bg-white/15 scale-110"
                    : "opacity-60 hover:opacity-100 hover:bg-white/5"
                )}
                title={cat.name}
              >
                {cat.icon}
              </button>
            ))}
          </div>

          <div className="max-h-56 overflow-y-auto px-1 py-1">
            <p className="mb-2 text-[10px] font-bold uppercase tracking-wider text-zinc-400">
              {EMOJI_CATEGORIES[activeCategory].name}
            </p>
            <div className="grid grid-cols-8 gap-1.5 text-center">
              {EMOJI_CATEGORIES[activeCategory].emojis.map((emoji) => (
                <button
                  key={emoji}
                  type="button"
                  onClick={() => onSelectEmoji(emoji)}
                  className="flex h-8 w-8 items-center justify-center rounded-lg text-lg transition-transform hover:scale-135 hover:bg-white/10 active:scale-95"
                >
                  {emoji}
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : (
        <div className="mt-2 max-h-64 overflow-y-auto px-1 py-2">
          <p className="mb-2 text-[10px] font-bold uppercase tracking-wider text-zinc-400">
            Expressive Stickers
          </p>
          <div className="grid grid-cols-6 gap-2 text-center">
            {CHAT_STICKERS.map((sticker) => (
              <button
                key={sticker}
                type="button"
                onClick={() => {
                  if (onSelectSticker) {
                    onSelectSticker(sticker);
                  } else {
                    onSelectEmoji(sticker);
                  }
                }}
                className="flex h-12 w-12 items-center justify-center rounded-2xl border border-white/5 bg-white/5 text-2xl transition hover:scale-120 hover:border-brand-purple/40 hover:bg-brand-purple/15 active:scale-90"
              >
                {sticker}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
