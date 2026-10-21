"use client";

import Link from "next/link";
import { useAuthStore } from "@/lib/stores";
import { cloudinaryUrl, cn, handleLabel, publicHandle } from "@/lib/utils";

export function AccountChip({ className }: { className?: string }) {
  const user = useAuthStore((s) => s.user);
  if (!user) return null;

  const handle = publicHandle(user);
  const displayName = user.displayName?.trim();
  const label = displayName || handleLabel(user);
  const initial = (displayName || handle || "U").charAt(0).toUpperCase();

  return (
    <Link
      href="/profile/me"
      className={cn(
        "flex max-w-[11.5rem] items-center gap-2 rounded-2xl border border-border/70 bg-surface-hover/60 py-1 pl-1 pr-2.5 transition duration-150 hover:border-brand-purple/40 hover:bg-surface-hover",
        className
      )}
    >
      {user.avatarUrl ? (
        <img
          src={cloudinaryUrl(user.avatarUrl, "c_fill,w_64,h_64,g_face")}
          alt=""
          className="h-7 w-7 shrink-0 rounded-full object-cover ring-1 ring-border"
        />
      ) : (
        <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-brand-purple/20 font-display text-xs font-bold text-brand-purple">
          {initial}
        </div>
      )}
      <span className="min-w-0 truncate font-display text-sm font-semibold text-foreground">
        {label}
      </span>
    </Link>
  );
}
