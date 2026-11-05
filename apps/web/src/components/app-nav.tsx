"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Home, MessageCircle, Plus, User, Compass, Bell, LogOut, Radio } from "lucide-react";
import { cn } from "@/lib/utils";
import { signOut } from "@/lib/api/auth";
import { disconnectSocket } from "@/lib/socket";
import { useAuthStore, useUiStore } from "@/lib/stores";

const items = [
  { href: "/home", label: "Home", icon: Home, match: ["/home"] },
  { href: "/explore", label: "Explore", icon: Compass, match: ["/explore", "/hashtags"] },
  { href: "__create__", label: "Create", icon: Plus, match: [] },
  { href: "/chats", label: "Chats", icon: MessageCircle, match: ["/chats", "/groups"] },
  { href: "/notifications", label: "Inbox", icon: Bell, match: ["/notifications"] },
  { href: "/profile/me", label: "Profile", icon: User, match: ["/profile"] },
];

export function BottomNav() {
  const pathname = usePathname();
  const unread = useAuthStore((s) => s.unreadTotal);
  const notificationUnread = useAuthStore((s) => s.notificationUnread);
  const setCreateOpen = useUiStore((s) => s.setCreateSheetOpen);

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 border-t border-border/80 bg-surface/90 backdrop-blur-2xl md:hidden">
      <div className="mx-auto flex h-[70px] max-w-lg items-center justify-around px-2">
        {items.map((item) => {
          if (item.href === "__create__") {
            return (
              <button
                key="create"
                type="button"
                onClick={() => setCreateOpen(true)}
                className="flex h-11 w-11 items-center justify-center rounded-2xl brand-gradient text-white shadow-lg shadow-brand-purple/30 transition hover:scale-105 active:scale-95"
                aria-label="Create"
              >
                <Plus className="h-5 w-5 stroke-[2.5]" />
              </button>
            );
          }
          const active = item.match.some((m) => pathname.startsWith(m));
          const badge =
            item.href === "/chats" && unread > 0
              ? unread > 99
                ? "99+"
                : unread
              : item.href === "/notifications" && notificationUnread > 0
                ? notificationUnread > 99
                  ? "99+"
                  : notificationUnread
                : null;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "relative flex flex-col items-center gap-1 px-3 py-1.5 text-xs font-semibold transition duration-150",
                active ? "text-brand-purple" : "text-muted hover:text-foreground"
              )}
            >
              <item.icon className={cn("h-5 w-5", active && "stroke-[2.5]")} />
              <span className="text-[11px]">{item.label}</span>
              {badge ? (
                <span className="absolute -right-1 top-0 flex h-4 min-w-4 items-center justify-center rounded-full bg-brand-purple px-1 text-[9px] font-black text-white">
                  {badge}
                </span>
              ) : null}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

export function SideNav() {
  const pathname = usePathname();
  const router = useRouter();
  const unread = useAuthStore((s) => s.unreadTotal);
  const notificationUnread = useAuthStore((s) => s.notificationUnread);
  const setCreateOpen = useUiStore((s) => s.setCreateSheetOpen);
  const setUser = useAuthStore((s) => s.setUser);
  const setAuthenticated = useAuthStore((s) => s.setAuthenticated);

  async function handleSignOut() {
    await signOut();
    disconnectSocket();
    setUser(null);
    setAuthenticated(false);
    router.push("/auth/sign-in");
  }

  return (
    <aside className="sticky top-0 hidden h-dvh w-64 shrink-0 flex-col self-start border-r border-border/70 bg-surface/40 p-5 backdrop-blur-xl md:flex z-30 overflow-y-auto">
      <Link href="/home" className="mb-8 flex items-center gap-2">
        <img src="/logo.png" alt="XLive" className="h-9 w-auto object-contain" />
      </Link>
      <div className="flex flex-col gap-1.5">
        {[
          ...items.filter((i) => i.href !== "__create__" && i.href !== "/profile/me"),
          { href: "/live", label: "Live", icon: Radio, match: ["/live"] },
          { href: "/profile/me", label: "Profile", icon: User, match: ["/profile"] },
        ].map((item) => {
          const active = item.match.some((m) => pathname.startsWith(m));
          const badge =
            item.href === "/chats" && unread > 0
              ? unread
              : item.href === "/notifications" && notificationUnread > 0
                ? notificationUnread
                : null;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3.5 rounded-2xl px-4 py-3 font-display text-sm font-semibold transition duration-150",
                active
                  ? "bg-brand-purple/15 text-brand-purple shadow-sm"
                  : "text-muted hover:bg-surface-hover hover:text-foreground"
              )}
            >
              <item.icon className={cn("h-5 w-5", active && "stroke-[2.5]")} />
              <span>{item.label}</span>
              {badge ? (
                <span className="ml-auto rounded-full bg-brand-purple px-2 py-0.5 text-xs font-bold text-white">
                  {badge > 99 ? "99+" : badge}
                </span>
              ) : null}
            </Link>
          );
        })}

        <button
          type="button"
          onClick={() => setCreateOpen(true)}
          className="mt-4 flex items-center justify-center gap-2.5 rounded-2xl brand-gradient px-4 py-3 font-display text-sm font-bold text-white shadow-lg shadow-brand-purple/25 transition duration-150 hover:opacity-95 active:scale-[0.98]"
        >
          <Plus className="h-5 w-5 stroke-[2.5]" />
          <span>Create Post / Live</span>
        </button>
      </div>
      <button
        type="button"
        onClick={handleSignOut}
        className="mt-auto flex items-center gap-3.5 rounded-2xl px-4 py-3 font-display text-sm font-semibold text-red-400 transition duration-150 hover:bg-red-500/10"
      >
        <LogOut className="h-5 w-5" />
        <span>Log out</span>
      </button>
    </aside>
  );
}
