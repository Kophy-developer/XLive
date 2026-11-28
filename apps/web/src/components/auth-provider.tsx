"use client";

import { useCallback, useEffect } from "react";
import { useAuthStore } from "@/lib/stores";
import { session } from "@/lib/session";
import { getMe } from "@/lib/api/auth";
import { getUnreadSummary } from "@/lib/api/chats";
import { getNotificationUnreadCount } from "@/lib/api/misc";
import { connectSocket, disconnectSocket, onSocketEvent, socketEvents } from "@/lib/socket";
import { useSocketFallbackPoll } from "@/lib/socket-fallback";

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, setUser, setLoading, setAuthenticated, setUnreadTotal, setNotificationUnread } = useAuthStore();

  useEffect(() => {
    let cancelled = false;

    async function hydrate() {
      if (!session.isAuthenticated()) {
        setAuthenticated(false);
        setUser(null);
        setNotificationUnread(0);
        setLoading(false);
        return;
      }
      try {
        const [user, unread, notifUnread] = await Promise.all([
          getMe(),
          getUnreadSummary().catch(() => ({ total: 0 })),
          getNotificationUnreadCount().catch(() => 0),
        ]);
        if (cancelled) return;
        setUser(user);
        setAuthenticated(true);
        setUnreadTotal(unread.total ?? 0);
        setNotificationUnread(notifUnread);
        connectSocket();
      } catch {
        if (cancelled) return;
        session.clear();
        setAuthenticated(false);
        setUser(null);
        setNotificationUnread(0);
        disconnectSocket();
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    hydrate();
    return () => {
      cancelled = true;
    };
  }, [setAuthenticated, setLoading, setNotificationUnread, setUnreadTotal, setUser]);

  useEffect(() => {
    const off = onSocketEvent<{ total?: number }>(socketEvents.unreadUpdated, (data) => {
      if (typeof data?.total === "number") setUnreadTotal(data.total);
    });
    return off;
  }, [setUnreadTotal]);

  const refreshNotifBadge = useCallback(async () => {
    if (!session.isAuthenticated()) return;
    try {
      const count = await getNotificationUnreadCount();
      setNotificationUnread(count);
    } catch {
      /* keep last known badge */
    }
  }, [setNotificationUnread]);

  useEffect(() => {
    const offCreated = onSocketEvent(socketEvents.notificationCreated, () => {
      void refreshNotifBadge();
    });
    return offCreated;
  }, [refreshNotifBadge]);

  useSocketFallbackPoll(refreshNotifBadge, { enabled: isAuthenticated });

  return <>{children}</>;
}
