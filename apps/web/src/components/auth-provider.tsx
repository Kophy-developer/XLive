"use client";

import { useEffect } from "react";
import { useAuthStore } from "@/lib/stores";
import { session } from "@/lib/session";
import { getMe } from "@/lib/api/auth";
import { getUnreadSummary } from "@/lib/api/chats";
import { connectSocket, disconnectSocket, onSocketEvent, socketEvents } from "@/lib/socket";

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const { setUser, setLoading, setAuthenticated, setUnreadTotal } = useAuthStore();

  useEffect(() => {
    let cancelled = false;

    async function hydrate() {
      if (!session.isAuthenticated()) {
        setAuthenticated(false);
        setUser(null);
        setLoading(false);
        return;
      }
      try {
        const [user, unread] = await Promise.all([getMe(), getUnreadSummary().catch(() => ({ total: 0 }))]);
        if (cancelled) return;
        setUser(user);
        setAuthenticated(true);
        setUnreadTotal(unread.total ?? 0);
        connectSocket();
      } catch {
        if (cancelled) return;
        session.clear();
        setAuthenticated(false);
        setUser(null);
        disconnectSocket();
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    hydrate();
    return () => {
      cancelled = true;
    };
  }, [setAuthenticated, setLoading, setUnreadTotal, setUser]);

  useEffect(() => {
    const off = onSocketEvent<{ total?: number }>(socketEvents.unreadUpdated, (data) => {
      if (typeof data?.total === "number") setUnreadTotal(data.total);
    });
    return off;
  }, [setUnreadTotal]);

  return <>{children}</>;
}
