"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect } from "react";
import { Bell } from "lucide-react";
import { refreshLiveNowCreators } from "@/lib/live-now";
import { useAuthStore } from "@/lib/stores";
import { AccountChip } from "./account-chip";
import { BottomNav, SideNav } from "./app-nav";
import { CreateSheet } from "./create-sheet";
import { cn } from "@/lib/utils";

function isLiveRoom(pathname: string) {
  const parts = pathname.split("/").filter(Boolean);
  return parts[0] === "live" && parts.length === 2 && parts[1] !== "setup" && parts[1] !== "replays";
}

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const liveRoom = isLiveRoom(pathname);
  const notificationUnread = useAuthStore((s) => s.notificationUnread);

  useEffect(() => {
    void refreshLiveNowCreators();
  }, []);

  return (
    <div className={cn("flex", liveRoom ? "h-dvh overflow-hidden" : "min-h-dvh")}>
      <SideNav />
      <div
        className={cn(
          "flex min-w-0 flex-1 flex-col",
          liveRoom ? "h-dvh min-h-0 overflow-hidden" : "min-h-dvh"
        )}
      >
        <header className="sticky top-0 z-30 flex h-14 shrink-0 items-center justify-between border-b border-border bg-surface/80 px-4 backdrop-blur-xl md:hidden">
          <Link href="/home" className="flex items-center">
            <img src="/logo.png" alt="XLive" className="h-8 w-auto object-contain" />
          </Link>
          <div className="flex items-center gap-1.5">
            <Link href="/notifications" className="relative rounded-lg p-2 hover:bg-border/30">
              <Bell className="h-5 w-5" />
              {notificationUnread > 0 ? (
                <span className="absolute right-0.5 top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-brand-purple px-1 text-[9px] font-black text-white">
                  {notificationUnread > 99 ? "99+" : notificationUnread}
                </span>
              ) : null}
            </Link>
            <AccountChip />
          </div>
        </header>
        <main className={cn("min-h-0 flex-1", liveRoom ? "overflow-hidden" : "pb-20 md:pb-6")}>
          {children}
        </main>
        <BottomNav />
        <CreateSheet />
      </div>
    </div>
  );
}
