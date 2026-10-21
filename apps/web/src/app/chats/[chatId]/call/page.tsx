"use client";

import { useParams, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { acceptDmCall, endDmCall, getActiveDmCall } from "@/lib/api/chats";
import {
  emitDmCallEnd,
  onSocketEvent,
  socketEvents,
} from "@/lib/socket";
import { useCallStore } from "@/lib/stores";
import {
  Mic,
  MicOff,
  PhoneOff,
  Video,
  VideoOff,
  Volume2,
} from "lucide-react";
import type {
  IAgoraRTCClient,
  ICameraVideoTrack,
  IMicrophoneAudioTrack,
  IAgoraRTCRemoteUser,
} from "agora-rtc-sdk-ng";

function CallContent() {
  const params = useParams();
  const searchParams = useSearchParams();
  const router = useRouter();
  const chatId = params.chatId as string;
  const callId = searchParams.get("callId") ?? "";
  const initialType = (searchParams.get("type") as "audio" | "video") ?? "video";
  const role = searchParams.get("role") ?? "caller";

  const localVideoRef = useRef<HTMLDivElement>(null);
  const remoteVideoRef = useRef<HTMLDivElement>(null);
  const clientRef = useRef<IAgoraRTCClient | null>(null);
  const localAudioTrackRef = useRef<IMicrophoneAudioTrack | null>(null);
  const localVideoTrackRef = useRef<ICameraVideoTrack | null>(null);
  const remoteUserRef = useRef<IAgoraRTCRemoteUser | null>(null);

  const [status, setStatus] = useState<"connecting" | "ringing" | "connected" | "ended" | "declined" | "failed">(
    role === "caller" ? "ringing" : "connecting"
  );
  const [duration, setDuration] = useState(0);
  const [isMuted, setIsMuted] = useState(false);
  const [isVideoOff, setIsVideoOff] = useState(initialType === "audio");
  const [remoteHasVideo, setRemoteHasVideo] = useState(false);
  const [errorMsg, setErrorMsg] = useState("");

  useEffect(() => {
    let timer: NodeJS.Timeout | null = null;
    if (status === "connected") {
      timer = setInterval(() => {
        setDuration((d) => d + 1);
      }, 1000);
    }
    return () => {
      if (timer) clearInterval(timer);
    };
  }, [status]);

  function formatDuration(sec: number) {
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  }

  useEffect(() => {
    let isCleanedUp = false;

    async function init() {
      try {
        let creds: { token?: string; appId?: string; channel?: string; uid?: string | number } | null = null;

        const stored = sessionStorage.getItem(`call_${callId}`);
        if (stored) {
          try {
            creds = JSON.parse(stored);
          } catch {
          }
        }

        if ((!creds || !creds.token || !creds.appId) && role === "callee") {
          const accepted = await acceptDmCall(callId);
          creds = {
            token: accepted.token,
            appId: accepted.appId,
            channel: accepted.channel,
            uid: accepted.uid,
          };
        }

        if ((!creds || !creds.token || !creds.appId) && role === "caller") {
          const active = await getActiveDmCall(chatId);
          if (active && active.token && active.appId) {
            creds = {
              token: active.token,
              appId: active.appId,
              channel: active.channel,
              uid: active.uid,
            };
          }
        }

        if (isCleanedUp) return;

        if (!creds?.token || !creds?.appId || !creds?.channel) {
          setErrorMsg("Call credentials not available");
          setStatus("failed");
          return;
        }

        const AgoraRTC = (await import("agora-rtc-sdk-ng")).default;
        AgoraRTC.setLogLevel(3);

        const client = AgoraRTC.createClient({ mode: "rtc", codec: "vp8" });
        clientRef.current = client;

        client.on("user-published", async (user, mediaType) => {
          remoteUserRef.current = user;
          await client.subscribe(user, mediaType);
          if (mediaType === "video") {
            setRemoteHasVideo(true);
            if (remoteVideoRef.current) {
              user.videoTrack?.play(remoteVideoRef.current);
            }
          }
          if (mediaType === "audio") {
            user.audioTrack?.play();
          }
          setStatus("connected");
          useCallStore.getState().setActiveCall(callId, initialType, {
            chatId,
            title: initialType === "video" ? "Video Call" : "Voice Call",
          });
        });

        client.on("user-unpublished", (_user, mediaType) => {
          if (mediaType === "video") {
            setRemoteHasVideo(false);
          }
        });

        client.on("user-left", () => {
          setStatus("ended");
          useCallStore.getState().clearActiveCall();
          setTimeout(() => {
            router.push(`/chats/${chatId}`);
          }, 1500);
        });

        await client.join(creds.appId, creds.channel, creds.token, creds.uid ?? null);

        if (isCleanedUp) return;

        const mic = await AgoraRTC.createMicrophoneAudioTrack();
        localAudioTrackRef.current = mic;

        if (initialType === "video") {
          try {
            const cam = await AgoraRTC.createCameraVideoTrack();
            localVideoTrackRef.current = cam;
            await client.publish([mic, cam]);
            if (localVideoRef.current) {
              cam.play(localVideoRef.current);
            }
          } catch {
            await client.publish([mic]);
            setIsVideoOff(true);
          }
        } else {
          await client.publish([mic]);
        }
      } catch (err) {
        if (!isCleanedUp) {
          setErrorMsg((err as Error).message || "Failed to establish call");
          setStatus("failed");
        }
      }
    }

    init();

    const offAccepted = onSocketEvent<Record<string, unknown>>(
      socketEvents.dmCallAccepted,
      (data) => {
        const id = String(data?.callId || data?.id || "");
        if (id === callId) {
          setStatus("connecting");
        }
      }
    );

    const offDeclined = onSocketEvent<Record<string, unknown>>(
      socketEvents.dmCallDeclined,
      (data) => {
        const id = String(data?.callId || data?.id || "");
        if (id === callId) {
          setStatus("declined");
          setTimeout(() => {
            router.push(`/chats/${chatId}`);
          }, 1500);
        }
      }
    );

    const offEnded = onSocketEvent<Record<string, unknown>>(
      socketEvents.dmCallEnded,
      (data) => {
        const id = String(data?.callId || data?.id || "");
        if (id === callId) {
          setStatus("ended");
          setTimeout(() => {
            router.push(`/chats/${chatId}`);
          }, 1500);
        }
      }
    );

    return () => {
      isCleanedUp = true;
      offAccepted();
      offDeclined();
      offEnded();
      if (localAudioTrackRef.current) {
        localAudioTrackRef.current.stop();
        localAudioTrackRef.current.close();
        localAudioTrackRef.current = null;
      }
      if (localVideoTrackRef.current) {
        localVideoTrackRef.current.stop();
        localVideoTrackRef.current.close();
        localVideoTrackRef.current = null;
      }
      if (clientRef.current) {
        clientRef.current.leave().catch(() => {});
        clientRef.current = null;
      }
      sessionStorage.removeItem(`call_${callId}`);
    };
  }, [callId, chatId, initialType, role, router]);

  async function toggleMute() {
    if (!localAudioTrackRef.current) return;
    const next = !isMuted;
    await localAudioTrackRef.current.setEnabled(!next);
    setIsMuted(next);
  }

  async function toggleVideo() {
    if (!localVideoTrackRef.current) {
      try {
        const AgoraRTC = (await import("agora-rtc-sdk-ng")).default;
        const cam = await AgoraRTC.createCameraVideoTrack();
        localVideoTrackRef.current = cam;
        if (clientRef.current) {
          await clientRef.current.publish([cam]);
        }
        if (localVideoRef.current) {
          cam.play(localVideoRef.current);
        }
        setIsVideoOff(false);
      } catch {
      }
      return;
    }
    const next = !isVideoOff;
    await localVideoTrackRef.current.setEnabled(!next);
    setIsVideoOff(next);
  }

  async function handleEnd() {
    setStatus("ended");
    useCallStore.getState().clearActiveCall();
    emitDmCallEnd(callId);
    try {
      await endDmCall(callId);
    } catch {
    }
    if (localAudioTrackRef.current) {
      localAudioTrackRef.current.stop();
      localAudioTrackRef.current.close();
      localAudioTrackRef.current = null;
    }
    if (localVideoTrackRef.current) {
      localVideoTrackRef.current.stop();
      localVideoTrackRef.current.close();
      localVideoTrackRef.current = null;
    }
    if (clientRef.current) {
      await clientRef.current.leave().catch(() => {});
      clientRef.current = null;
    }
    router.push(`/chats/${chatId}`);
  }

  return (
    <div className="relative flex h-dvh w-full flex-col overflow-hidden bg-[#0a0a10] text-white select-none">
      <div className="absolute inset-x-0 top-0 z-30 flex items-center justify-center p-4 bg-gradient-to-b from-black/80 via-black/40 to-transparent">
        <div className="flex flex-col items-center">
          <span className="font-sans text-xs font-semibold uppercase tracking-wider text-zinc-300">
            {initialType === "video" ? "Video Call" : "Voice Call"}
          </span>
          <span className="font-sans text-sm font-bold text-white tracking-tight tabular-nums">
            {status === "connected"
              ? formatDuration(duration)
              : status === "ringing"
              ? "Ringing…"
              : status === "connecting"
              ? "Connecting…"
              : status === "declined"
              ? "Call Declined"
              : status === "failed"
              ? "Connection Failed"
              : "Call Ended"}
          </span>
        </div>
      </div>

      <div className="relative flex flex-1 items-center justify-center bg-[#07070c]">
        {initialType === "video" && (
          <div
            ref={remoteVideoRef}
            className={`absolute inset-0 h-full w-full object-cover transition-opacity duration-300 ${
              remoteHasVideo ? "opacity-100" : "opacity-0"
            }`}
          />
        )}

        {(!remoteHasVideo || initialType === "audio") && (
          <div className="flex flex-col items-center justify-center z-10 px-4 text-center">
            <div className="relative mb-6">
              <div className="absolute -inset-4 rounded-full brand-gradient opacity-20 blur-xl animate-pulse" />
              <div className="relative flex h-32 w-32 items-center justify-center rounded-full border-2 border-brand-purple/40 bg-[#161626] shadow-2xl">
                {initialType === "video" ? (
                  <Video className="h-12 w-12 text-brand-purple" />
                ) : (
                  <Volume2 className="h-12 w-12 text-brand-purple animate-pulse" />
                )}
              </div>
            </div>

            <h3 className="font-sans text-xl font-bold text-white tracking-tight">
              {status === "connected"
                ? "In Call"
                : status === "ringing"
                ? "Ringing…"
                : status === "connecting"
                ? "Connecting…"
                : status === "declined"
                ? "Call Declined"
                : status === "failed"
                ? errorMsg || "Failed to Connect"
                : "Call Ended"}
            </h3>
            <p className="mt-1 text-xs text-zinc-400">
              {status === "connected"
                ? "Encrypted direct call"
                : status === "ringing"
                ? "Waiting for response…"
                : status === "failed"
                ? "Please check connection & device permissions"
                : ""}
            </p>
          </div>
        )}

        {initialType === "video" && (
          <div
            className={`absolute bottom-28 right-4 z-20 h-44 w-32 overflow-hidden rounded-2xl border border-white/20 bg-black/80 shadow-2xl transition-all ${
              isVideoOff ? "hidden" : "block"
            }`}
          >
            <div ref={localVideoRef} className="h-full w-full object-cover" />
          </div>
        )}
      </div>

      <div className="absolute inset-x-0 bottom-0 z-30 flex items-center justify-center gap-4 pb-8 pt-4 bg-gradient-to-t from-black/90 via-black/50 to-transparent">
        <button
          type="button"
          onClick={toggleMute}
          className={`flex h-14 w-14 items-center justify-center rounded-2xl border transition active:scale-95 ${
            isMuted
              ? "border-red-500/40 bg-red-500/20 text-red-400 shadow-lg shadow-red-500/20"
              : "border-white/10 bg-white/10 text-white hover:bg-white/20"
          }`}
        >
          {isMuted ? <MicOff className="h-6 w-6" /> : <Mic className="h-6 w-6" />}
        </button>

        <button
          type="button"
          onClick={handleEnd}
          className="flex h-16 w-16 items-center justify-center rounded-3xl bg-red-500 text-white shadow-xl shadow-red-500/30 transition hover:bg-red-600 active:scale-95"
        >
          <PhoneOff className="h-7 w-7" />
        </button>

        {initialType === "video" && (
          <button
            type="button"
            onClick={toggleVideo}
            className={`flex h-14 w-14 items-center justify-center rounded-2xl border transition active:scale-95 ${
              isVideoOff
                ? "border-red-500/40 bg-red-500/20 text-red-400 shadow-lg shadow-red-500/20"
                : "border-white/10 bg-white/10 text-white hover:bg-white/20"
            }`}
          >
            {isVideoOff ? <VideoOff className="h-6 w-6" /> : <Video className="h-6 w-6" />}
          </button>
        )}
      </div>
    </div>
  );
}

export default function DmCallPage() {
  return (
    <AuthGuard>
      <Suspense>
        <CallContent />
      </Suspense>
    </AuthGuard>
  );
}
