"use client";

import { useEffect, useRef } from "react";
import { isSocketConnected, onSocketConnection } from "./socket";

const FALLBACK_INTERVAL_MS = 45_000;

/**
 * Runs `poll` immediately on mount, reconnect, disconnect, and when the tab
 * becomes visible or focused. Repeats every 45s only while the socket is down
 * and the tab is visible.
 */
export function useSocketFallbackPoll(
  poll: () => void | Promise<void>,
  options?: { enabled?: boolean; intervalMs?: number }
) {
  const pollRef = useRef(poll);
  pollRef.current = poll;
  const enabled = options?.enabled ?? true;
  const intervalMs = options?.intervalMs ?? FALLBACK_INTERVAL_MS;

  useEffect(() => {
    if (!enabled) return;
    let timer: number | undefined;
    const visible = () => typeof document !== "undefined" && document.visibilityState === "visible";
    const run = () => {
      if (visible()) void pollRef.current();
    };
    const arm = () => {
      if (timer != null) window.clearInterval(timer);
      timer = undefined;
      if (visible() && !isSocketConnected()) {
        timer = window.setInterval(run, intervalMs);
      }
    };
    const catchUpAndArm = () => {
      run();
      arm();
    };

    const off = onSocketConnection(() => catchUpAndArm());
    document.addEventListener("visibilitychange", catchUpAndArm);
    window.addEventListener("focus", catchUpAndArm);
    return () => {
      off();
      document.removeEventListener("visibilitychange", catchUpAndArm);
      window.removeEventListener("focus", catchUpAndArm);
      if (timer != null) window.clearInterval(timer);
    };
  }, [enabled, intervalMs]);
}
