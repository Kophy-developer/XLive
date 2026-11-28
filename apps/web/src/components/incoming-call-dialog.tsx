"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { usePathname, useRouter } from "next/navigation";
import { Phone, PhoneOff, Video, ArrowUpRight } from "lucide-react";
import { acceptDmCall, declineDmCall, endDmCall, endGroupCall, getActiveDmCall } from "@/lib/api/chats";
import { api } from "@/lib/api/client";
import { session } from "@/lib/session";
import {
  emitDmCallAccept,
  emitDmCallDecline,
  emitDmCallEnd,
  emitGroupCallEnd,
  emitGroupCallJoin,
  onSocketEvent,
  socketEvents,
} from "@/lib/socket";
import { useSocketFallbackPoll } from "@/lib/socket-fallback";
import { useAuthStore, useCallStore } from "@/lib/stores";

type IncomingCall = {
  isGroup: boolean;
  callId: string;
  callType: "audio" | "video";
  chatId?: string;
  groupId?: string;
  callerName: string;
  callerAvatar?: string;
};

export function IncomingCallDialog() {
  const router = useRouter();
  const currentUserId = useAuthStore((s) => s.user?.id);
  const setActiveCall = useCallStore((s) => s.setActiveCall);
  const clearActiveCall = useCallStore((s) => s.clearActiveCall);
  const [call, setCall] = useState<IncomingCall | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const ringIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const handledCallsRef = useRef<Set<string>>(new Set());

  const startRingtone = useCallback(() => {
    try {
      const AudioCtx =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      audioContextRef.current = ctx;
      if (ctx.state === "suspended") {
        ctx.resume().catch(() => {});
      }

      const playChime = () => {
        if (!audioContextRef.current || audioContextRef.current.state === "closed") return;
        const now = audioContextRef.current.currentTime;
        const osc1 = audioContextRef.current.createOscillator();
        const osc2 = audioContextRef.current.createOscillator();
        const gain = audioContextRef.current.createGain();

        osc1.type = "sine";
        osc1.frequency.setValueAtTime(440, now);
        osc1.frequency.exponentialRampToValueAtTime(480, now + 0.35);

        osc2.type = "sine";
        osc2.frequency.setValueAtTime(480, now);
        osc2.frequency.exponentialRampToValueAtTime(520, now + 0.35);

        gain.gain.setValueAtTime(0, now);
        gain.gain.linearRampToValueAtTime(0.12, now + 0.05);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.4);

        osc1.connect(gain);
        osc2.connect(gain);
        gain.connect(audioContextRef.current.destination);

        osc1.start(now);
        osc2.start(now);
        osc1.stop(now + 0.45);
        osc2.stop(now + 0.45);
      };

      playChime();
      ringIntervalRef.current = setInterval(playChime, 2000);
    } catch {
    }
  }, []);

  const stopRingtone = useCallback(() => {
    if (ringIntervalRef.current) {
      clearInterval(ringIntervalRef.current);
      ringIntervalRef.current = null;
    }
    if (audioContextRef.current) {
      audioContextRef.current.close().catch(() => {});
      audioContextRef.current = null;
    }
  }, []);

  const handleIncomingDm = useCallback((data: unknown) => {
    if (typeof window !== "undefined" && window.location.pathname.includes("/call")) return;
    const raw = (Array.isArray(data) ? data[0] : data) as Record<string, unknown> | null;
    if (!raw) return;
    const callObj = (raw.call && typeof raw.call === "object" ? raw.call : raw) as Record<string, unknown>;
    const callId = String(callObj._id || callObj.id || callObj.callId || raw.callId || raw.id || raw._id || "");
    if (!callId) return;

    if (handledCallsRef.current.has(callId)) return;

    const callerObj = (raw.caller && typeof raw.caller === "object" ? raw.caller : {}) as Record<string, unknown>;
    const resolvedUserId = currentUserId || useAuthStore.getState().user?.id;
    const peerUserId = String(
      raw.callerId ||
      raw.peerUserId ||
      callObj.callerId ||
      callObj.peerUserId ||
      callerObj._id ||
      callerObj.id ||
      ""
    );
    if (peerUserId && resolvedUserId && peerUserId === resolvedUserId) return;

    const type = (callObj.type || callObj.callType || raw.callType || raw.type) === "audio" ? "audio" : "video";
    const chatId = String(raw.chatId || callObj.chatId || "");
    const callerName = String(
      raw.callerName ||
      raw.peerName ||
      callObj.callerName ||
      callerObj.username ||
      callerObj.handle ||
      "Someone"
    );
    const callerAvatar = String(
      raw.callerAvatarUrl ||
      raw.callerAvatar ||
      raw.avatarUrl ||
      callObj.callerAvatarUrl ||
      callObj.callerAvatar ||
      callerObj.avatarUrl ||
      ""
    );

    const channel = String(callObj.channel || callObj.agoraChannel || "");
    const token = callObj.token ? String(callObj.token) : undefined;
    const appId = callObj.appId ? String(callObj.appId) : undefined;
    const uid = (callObj.uid as string | number | undefined);

    if (token && appId) {
      sessionStorage.setItem(
        `call_${callId}`,
        JSON.stringify({
          id: callId,
          chatId,
          callerId: peerUserId,
          type,
          status: "ringing",
          channel,
          token,
          appId,
          uid,
        })
      );
    }

    setCall({
      isGroup: false,
      callId,
      callType: type,
      chatId,
      callerName,
      callerAvatar,
    });
    startRingtone();
  }, [currentUserId, startRingtone]);

  useEffect(() => {
    const offDmIncoming = onSocketEvent<unknown>(
      socketEvents.dmCallIncoming,
      handleIncomingDm
    );

    const offNotificationCreated = onSocketEvent<Record<string, unknown>>(
      socketEvents.notificationCreated,
      (data) => {
        const notif = (data?.notification && typeof data.notification === "object" ? data.notification : data) as Record<string, unknown> | null;
        if (!notif) return;
        const notifType = String(notif.type || "");
        if (notifType !== "dm_call" && notifType !== "call") return;

        const notifData = (notif.data && typeof notif.data === "object" ? notif.data : {}) as Record<string, unknown>;
        const actor = (notif.actor && typeof notif.actor === "object" ? notif.actor : {}) as Record<string, unknown>;
        handleIncomingDm({
          callId: notifData.callId || notifData.id,
          chatId: notifData.chatId,
          type: notifData.callType || notifData.type,
          callerId: notifData.callerId || actor.id || actor._id,
          callerName: actor.username || actor.displayName || notif.title,
          callerAvatarUrl: actor.avatarUrl,
        });
      }
    );

    const offGroupStarted = onSocketEvent<unknown>(
      socketEvents.groupCallStarted,
      (data) => {
        if (typeof window !== "undefined" && window.location.pathname.includes("/call")) return;
        const raw = (Array.isArray(data) ? data[0] : data) as Record<string, unknown> | null;
        if (!raw) return;
        const callObj = (raw.call && typeof raw.call === "object" ? raw.call : raw) as Record<string, unknown>;
        const callId = String(callObj._id || callObj.id || callObj.callId || raw.callId || raw.id || "");
        const groupId = String(raw.groupId || callObj.groupId || "");
        if (!callId || !groupId) return;
        if (handledCallsRef.current.has(callId)) return;

        const resolvedUserId = currentUserId || useAuthStore.getState().user?.id;
        const starterId = String(raw.userId || raw.starterId || callObj.starterId || callObj.userId || "");
        if (starterId && resolvedUserId && starterId === resolvedUserId) return;

        const type = (callObj.type || callObj.callType || raw.callType || raw.type) === "audio" ? "audio" : "video";
        const groupName = String(raw.groupName || callObj.groupName || "Group");
        const callerName = String(raw.callerName || callObj.callerName || "A member");
        const callerAvatar = String(raw.groupAvatar || raw.callerAvatarUrl || raw.avatarUrl || "");

        setCall({
          isGroup: true,
          callId,
          callType: type,
          groupId,
          callerName: `${groupName} (${callerName})`,
          callerAvatar,
        });
        startRingtone();
      }
    );

    const offDmEnded = onSocketEvent<unknown>(
      socketEvents.dmCallEnded,
      (data) => {
        const raw = (Array.isArray(data) ? data[0] : data) as Record<string, unknown> | null;
        const callObj = (raw?.call && typeof raw.call === "object" ? raw.call : raw) as Record<string, unknown> | null;
        const endedId = String(callObj?._id || callObj?.id || callObj?.callId || raw?.callId || raw?.id || "");
        setCall((current) => {
          if (!current || (endedId && current.callId !== endedId)) return current;
          stopRingtone();
          return null;
        });
        clearActiveCall();
      }
    );

    const offDmDeclined = onSocketEvent<unknown>(
      socketEvents.dmCallDeclined,
      (data) => {
        const raw = (Array.isArray(data) ? data[0] : data) as Record<string, unknown> | null;
        const callObj = (raw?.call && typeof raw.call === "object" ? raw.call : raw) as Record<string, unknown> | null;
        const declinedId = String(callObj?._id || callObj?.id || callObj?.callId || raw?.callId || raw?.id || "");
        setCall((current) => {
          if (!current || (declinedId && current.callId !== declinedId)) return current;
          stopRingtone();
          return null;
        });
      }
    );

    const offGroupEnded = onSocketEvent<unknown>(
      socketEvents.groupCallEnded,
      (data) => {
        const raw = (Array.isArray(data) ? data[0] : data) as Record<string, unknown> | null;
        const callObj = (raw?.call && typeof raw.call === "object" ? raw.call : raw) as Record<string, unknown> | null;
        const endedId = String(callObj?._id || callObj?.id || callObj?.callId || raw?.callId || raw?.id || "");
        setCall((current) => {
          if (!current || (endedId && current.callId !== endedId)) return current;
          stopRingtone();
          return null;
        });
        clearActiveCall();
      }
    );

    return () => {
      offDmIncoming();
      offNotificationCreated();
      offGroupStarted();
      offDmEnded();
      offDmDeclined();
      offGroupEnded();
      stopRingtone();
    };
  }, [currentUserId, clearActiveCall, handleIncomingDm, stopRingtone, startRingtone]);

  const pathname = usePathname();
  const scanIncomingCalls = useCallback(async () => {
    if (call) return;
    if (pathname.includes("/call")) return;
    if (!session.isAuthenticated()) return;
    try {
      const res = await api.get<Record<string, unknown>>("/api/x-live/notifications?limit=3");
      const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown>;
      const docs = (Array.isArray(data?.docs) ? data.docs : Array.isArray(data?.items) ? data.items : []) as Record<string, unknown>[];

      for (const notif of docs) {
        const type = String(notif.type || "");
        if (type !== "dm_call" && type !== "call") continue;

        const createdAt = String(notif.createdAt || "");
        if (createdAt) {
          const ageMs = Date.now() - new Date(createdAt).getTime();
          if (ageMs > 50_000) continue;
        }

        const notifData = (notif.data && typeof notif.data === "object" ? notif.data : {}) as Record<string, unknown>;
        const actor = (notif.actor && typeof notif.actor === "object" ? notif.actor : {}) as Record<string, unknown>;
        const callId = String(notifData.callId || notifData.id || notif.id || "");
        if (!callId || handledCallsRef.current.has(callId)) continue;

        const chatId = String(notifData.chatId || "");
        if (!chatId) continue;

        const active = await getActiveDmCall(chatId);
        if (active && (active.status === "ringing" || active.status === "active") && active.id === callId) {
          handleIncomingDm({
            call: {
              id: callId,
              callId,
              chatId,
              type: notifData.callType || notifData.type || active.type,
              callerId: notifData.callerId || actor.id || actor._id,
              channel: active.channel,
              token: active.token,
              appId: active.appId,
              uid: active.uid,
            },
            chatId,
            callerId: notifData.callerId || actor.id || actor._id,
            callerName: actor.username || actor.displayName || notif.title,
            callerAvatarUrl: actor.avatarUrl,
          });
          break;
        }
      }
    } catch {
    }
  }, [call, handleIncomingDm, pathname]);

  useSocketFallbackPoll(scanIncomingCalls, { enabled: Boolean(currentUserId) });

  useEffect(() => {
    if (!call || call.isGroup || !call.chatId) return;

    const checkActive = setInterval(async () => {
      try {
        const active = await getActiveDmCall(call.chatId!);
        if (!active || active.id !== call.callId || active.status === "ended" || active.status === "declined") {
          stopRingtone();
          setCall(null);
        }
      } catch {
      }
    }, 2000);

    return () => clearInterval(checkActive);
  }, [call, stopRingtone]);

  async function handleAccept() {
    if (!call) return;
    stopRingtone();
    const active = call;
    handledCallsRef.current.add(active.callId);
    setCall(null);
    try {
      if (active.isGroup) {
        emitGroupCallJoin(active.callId);
        setActiveCall(active.callId, active.callType, {
          groupId: active.groupId,
          title: active.callerName,
          avatarUrl: active.callerAvatar,
        });
        router.push(`/groups/${active.groupId}/call?callId=${active.callId}&type=${active.callType}`);
      } else {
        const creds = await acceptDmCall(active.callId);
        emitDmCallAccept(active.callId);
        if (creds.token) {
          sessionStorage.setItem(`call_${active.callId}`, JSON.stringify(creds));
        }
        setActiveCall(active.callId, active.callType, {
          chatId: active.chatId,
          title: active.callerName,
          avatarUrl: active.callerAvatar,
        });
        router.push(`/chats/${active.chatId}/call?callId=${active.callId}&type=${active.callType}&role=callee`);
      }
    } catch {
      setCall(null);
    }
  }

  async function handleDecline() {
    if (!call) return;
    stopRingtone();
    const active = call;
    handledCallsRef.current.add(active.callId);
    setCall(null);
    try {
      if (!active.isGroup && active.callId) {
        emitDmCallDecline(active.callId);
        await declineDmCall(active.callId);
      }
    } catch {
    }
  }

  if (!call) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-md p-4 animate-in fade-in duration-200">
      <div className="w-full max-w-sm rounded-[28px] border border-white/10 bg-[#161622]/95 p-6 shadow-2xl backdrop-blur-2xl text-center animate-in zoom-in-95 duration-200">
        <div className="mx-auto h-20 w-20 overflow-hidden rounded-2xl border-2 border-white/15 shadow-xl bg-surface-hover flex items-center justify-center">
          {call.callerAvatar ? (
            <img src={call.callerAvatar} alt="" className="h-full w-full object-cover" />
          ) : call.callType === "video" ? (
            <Video className="h-8 w-8 text-brand-purple" />
          ) : (
            <Phone className="h-8 w-8 text-brand-purple" />
          )}
        </div>

        <h3 className="mt-4 font-sans text-xl font-bold text-white tracking-tight">
          Incoming {call.callType} call
        </h3>
        <p className="mt-1 text-xs text-zinc-400">
          {call.callerName} is calling you
        </p>

        <div className="mt-6 flex items-center gap-3">
          <button
            type="button"
            onClick={handleDecline}
            className="flex-1 h-12 rounded-2xl border border-white/15 bg-white/5 font-semibold text-white transition hover:bg-white/10 active:scale-95"
          >
            Decline
          </button>
          <button
            type="button"
            onClick={handleAccept}
            className="flex-1 h-12 rounded-2xl brand-gradient font-bold text-white shadow-lg shadow-brand-purple/30 transition hover:opacity-95 active:scale-95"
          >
            Accept
          </button>
        </div>
      </div>
    </div>
  );
}

export function OngoingCallBanner() {
  const router = useRouter();
  const pathname = usePathname();
  const activeCall = useCallStore((s) => s.activeCall);
  const clearActiveCall = useCallStore((s) => s.clearActiveCall);
  const [duration, setDuration] = useState(0);

  useEffect(() => {
    if (!activeCall) return;
    const start = activeCall.startedAt || Date.now();
    setDuration(Math.floor((Date.now() - start) / 1000));
    const timer = setInterval(() => {
      setDuration(Math.floor((Date.now() - start) / 1000));
    }, 1000);
    return () => clearInterval(timer);
  }, [activeCall]);

  if (!activeCall || pathname.includes("/call")) return null;

  const m = Math.floor(duration / 60);
  const s = duration % 60;
  const timeFormatted = `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;

  function handleReturn() {
    if (!activeCall) return;
    if (activeCall.groupId) {
      router.push(`/groups/${activeCall.groupId}/call?callId=${activeCall.callId}&type=${activeCall.callType}`);
    } else if (activeCall.chatId) {
      router.push(`/chats/${activeCall.chatId}/call?callId=${activeCall.callId}&type=${activeCall.callType}`);
    }
  }

  async function handleEnd() {
    if (!activeCall) return;
    const { callId, groupId } = activeCall;
    clearActiveCall();
    if (!callId) return;
    try {
      if (groupId) {
        emitGroupCallEnd(callId);
        await endGroupCall(callId);
      } else {
        emitDmCallEnd(callId);
        await endDmCall(callId);
      }
    } catch {
    }
  }

  return (
    <aside aria-label="Ongoing call" className="fixed top-4 inset-x-0 z-40 mx-auto max-w-md px-4 pointer-events-none">
      <div className="pointer-events-auto flex items-center justify-between gap-3 rounded-2xl border border-emerald-500/30 bg-[#12121e]/95 p-3 shadow-2xl shadow-emerald-500/10 backdrop-blur-2xl animate-in slide-in-from-top-3 duration-200">
        <div className="flex items-center gap-2.5 min-w-0">
          <span className="relative flex h-2.5 w-2.5 shrink-0">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
            <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500" />
          </span>
          <div className="min-w-0">
            <p className="truncate text-xs font-bold text-white">
              Ongoing {activeCall.callType} call • {activeCall.title}
            </p>
            <p className="text-[10px] text-emerald-400 tabular-nums font-semibold">
              {timeFormatted}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-1.5 shrink-0">
          <button
            type="button"
            onClick={handleReturn}
            className="flex items-center gap-1 rounded-xl brand-gradient px-3 py-1.5 text-xs font-bold text-white shadow-md shadow-brand-purple/20 transition hover:opacity-95 active:scale-95"
          >
            <span>Return</span>
            <ArrowUpRight className="h-3.5 w-3.5" />
          </button>
          <button
            type="button"
            onClick={handleEnd}
            className="flex h-8 w-8 items-center justify-center rounded-xl bg-red-500/20 text-red-400 hover:bg-red-500/30 hover:text-red-300 transition active:scale-95"
            title="End Call"
          >
            <PhoneOff className="h-4 w-4" />
          </button>
        </div>
      </div>
    </aside>
  );
}
