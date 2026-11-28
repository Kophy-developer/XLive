"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { AccountChip } from "@/components/account-chip";
import { signOut } from "@/lib/api/auth";
import {
  getNotification,
  getNotificationUnreadCount,
  getNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from "@/lib/api/misc";
import { onSocketEvent, socketEvents } from "@/lib/socket";
import { useSocketFallbackPoll } from "@/lib/socket-fallback";
import { useAuthStore } from "@/lib/stores";
import type { NotificationItem } from "@/lib/types";
import { cloudinaryUrl, cn } from "@/lib/utils";
import { ArrowLeft, Bell, Wallet, Radio, Phone, MessageCircle } from "lucide-react";

function formatTimeAgo(dateStr?: string) {
  if (!dateStr) return "";
  const diffSec = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
  if (diffSec < 60) return "1m";
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m`;
  const diffHours = Math.floor(diffMin / 60);
  if (diffHours < 24) return `${diffHours}h`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d`;
}

export default function NotificationsPage() {
  const router = useRouter();
  const setNotificationUnread = useAuthStore((s) => s.setNotificationUnread);
  const [unreadFilter, setUnreadFilter] = useState(false);
  const [readIds, setReadIds] = useState<Set<string>>(new Set());

  const queryClient = useQueryClient();
  const { data, isLoading, refetch } = useQuery({
    queryKey: ["notifications"],
    queryFn: () => getNotifications(1, 50),
    refetchOnWindowFocus: true,
  });

  const rawItems = data?.notifications ?? [];

  useQuery({
    queryKey: ["notifications-unread-count"],
    queryFn: async () => {
      const count = await getNotificationUnreadCount();
      setNotificationUnread(count);
      return count;
    },
    refetchOnWindowFocus: true,
  });

  const refreshNotifications = useCallback(() => {
    void queryClient.invalidateQueries({ queryKey: ["notifications"] });
    void queryClient.invalidateQueries({ queryKey: ["notifications-unread-count"] });
  }, [queryClient]);

  useEffect(() => {
    return onSocketEvent(socketEvents.notificationCreated, refreshNotifications);
  }, [refreshNotifications]);

  useSocketFallbackPoll(refreshNotifications);

  const items = rawItems.filter((n) => {
    const isUnread = !n.readAt && !n.read && !readIds.has(n.id);
    if (unreadFilter) return isUnread;
    return true;
  });

  async function refreshUnreadBadge() {
    try {
      const count = await getNotificationUnreadCount();
      setNotificationUnread(count);
    } catch {
      /* keep last badge */
    }
  }

  async function handleMarkAllRead() {
    try {
      await markAllNotificationsRead();
      const allIds = new Set(rawItems.map((n) => n.id));
      setReadIds(allIds);
      setNotificationUnread(0);
      refetch();
    } catch {
    }
  }

  async function resolveAndOpen(n: NotificationItem) {
    let item = n;
    const d0 = (item.data ?? {}) as Record<string, unknown>;
    if (!d0.chatId && !d0.groupId && !d0.streamId && !item.targetUrl && item.id) {
      const full = await getNotification(item.id).catch(() => null);
      if (full) item = full;
    }
    const d = (item.data ?? {}) as Record<string, unknown>;
    const type = String(item.type ?? d.type ?? "");

    if (d.chatId) {
      router.push(`/chats/${d.chatId}`);
    } else if (d.groupId) {
      router.push(`/groups/${d.groupId}`);
    } else if (d.streamId) {
      router.push(`/live/${d.streamId}`);
    } else if (type.includes("wallet") || d.paymentId) {
      router.push("/wallet");
    } else if (item.targetUrl) {
      router.push(item.targetUrl);
    }
  }

  async function handleNotificationClick(n: NotificationItem) {
    if (!n.readAt && !n.read) {
      setReadIds((prev) => new Set(prev).add(n.id));
      markNotificationRead(n.id)
        .then(() => refreshUnreadBadge())
        .catch(() => {});
    }
    await resolveAndOpen(n);
  }

  return (
    <AuthGuard>
      <div className="mx-auto max-w-4xl px-4 py-6 md:px-8">
        <header className="mb-8 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => router.push("/home")}
              className="flex h-10 w-10 items-center justify-center rounded-2xl bg-white/5 border border-white/10 text-white transition hover:bg-white/10 active:scale-95"
            >
              <ArrowLeft className="h-5 w-5" />
            </button>
            <div className="flex items-center gap-2">
              <img src="/logo.png" alt="XLive" className="h-7 w-auto object-contain" />
              <h1 className="font-sans text-2xl font-bold text-white tracking-tight">Inbox</h1>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <AccountChip className="hidden md:flex" />
            <button
              type="button"
              onClick={() => signOut()}
              className="rounded-2xl border border-white/15 bg-white/5 px-3 py-1.5 text-xs font-semibold text-zinc-300 transition hover:bg-white/10 hover:text-white"
            >
              Log out
            </button>
          </div>
        </header>

        <section>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-sans text-lg font-bold text-white tracking-tight">Activities</h2>

            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setUnreadFilter((prev) => !prev)}
                className={cn(
                  "rounded-full px-4 py-1.5 text-xs font-bold transition active:scale-95",
                  unreadFilter
                    ? "brand-gradient text-white shadow-md shadow-brand-purple/20"
                    : "border border-white/15 bg-white/5 text-zinc-300 hover:bg-white/10 hover:text-white"
                )}
              >
                Unread
              </button>

              <button
                type="button"
                onClick={handleMarkAllRead}
                className="rounded-full border border-white/15 bg-white/5 px-4 py-1.5 text-xs font-bold text-zinc-300 transition hover:bg-white/10 hover:text-white active:scale-95"
              >
                Mark all read
              </button>
            </div>
          </div>

          {isLoading ? (
            <div className="flex justify-center py-24">
              <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
            </div>
          ) : !items.length ? (
            <div className="flex flex-col items-center justify-center rounded-3xl border border-white/10 bg-[#141422]/60 py-24 text-center backdrop-blur-xl">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-white/5 text-zinc-400">
                <Bell className="h-6 w-6 opacity-60" />
              </div>
              <p className="mt-4 font-sans text-base font-bold text-white">All caught up</p>
              <p className="mt-1 text-xs text-zinc-400">
                {unreadFilter ? "No unread activities" : "You have no notifications right now"}
              </p>
            </div>
          ) : (
            <div className="space-y-2">
              {items.map((n) => {
                const isUnread = !n.readAt && !n.read && !readIds.has(n.id);
                const type = String(n.type || "");
                const isCall = type.includes("call");
                const isWallet = type.includes("wallet");
                const isLive = type.includes("live") || type.includes("stream");
                const isMessage = type.includes("message");

                return (
                  <div
                    key={n.id}
                    onClick={() => handleNotificationClick(n)}
                    className={cn(
                      "group flex cursor-pointer items-center justify-between gap-4 rounded-2xl border px-4 py-3.5 transition backdrop-blur-xl active:scale-[0.99]",
                      isUnread
                        ? "border-brand-purple/35 bg-[#18152b]/80 hover:bg-[#1f1b38]"
                        : "border-white/5 bg-[#141422]/60 hover:border-white/15 hover:bg-[#18182a]"
                    )}
                  >
                    <div className="flex min-w-0 items-center gap-3.5">
                      {n.actor?.avatarUrl ? (
                        <img
                          src={cloudinaryUrl(n.actor.avatarUrl, "c_fill,w_90,h_90,g_face")}
                          alt=""
                          className="h-10 w-10 shrink-0 rounded-full border border-white/15 object-cover shadow-sm"
                        />
                      ) : isWallet ? (
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-pink-500/20 text-pink-400 font-bold text-xs border border-pink-500/30">
                          <Wallet className="h-5 w-5" />
                        </div>
                      ) : isCall ? (
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                          <Phone className="h-5 w-5" />
                        </div>
                      ) : isLive ? (
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-purple/20 text-brand-purple border border-brand-purple/30">
                          <Radio className="h-5 w-5" />
                        </div>
                      ) : isMessage ? (
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-sky-500/20 text-sky-400 border border-sky-500/30">
                          <MessageCircle className="h-5 w-5" />
                        </div>
                      ) : (
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white/10 text-zinc-300 border border-white/10">
                          <Bell className="h-5 w-5" />
                        </div>
                      )}

                      <div className="min-w-0">
                        <h4 className="truncate font-sans text-sm font-bold text-white tracking-tight">
                          {n.title}
                        </h4>
                        {n.body ? (
                          <p className="truncate text-xs text-zinc-400 mt-0.5">
                            {n.body}
                          </p>
                        ) : null}
                      </div>
                    </div>

                    <div className="flex items-center gap-3 shrink-0">
                      {isUnread && (
                        <span className="h-2 w-2 rounded-full bg-pink-500 shadow-sm shadow-pink-500/50" />
                      )}
                      <span className="font-sans text-xs text-zinc-400 tabular-nums font-semibold">
                        {formatTimeAgo(n.createdAt)}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>
      </div>
    </AuthGuard>
  );
}
