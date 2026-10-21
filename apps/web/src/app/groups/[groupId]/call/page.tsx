"use client";

import { useParams, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { endGroupCall, joinGroupCall, leaveGroupCall } from "@/lib/api/chats";
import {
  emitGroupCallEnd,
  emitGroupCallLeave,
  onSocketEvent,
  socketEvents,
} from "@/lib/socket";
import { useCallStore } from "@/lib/stores";
import {
  Mic,
  MicOff,
  PhoneOff,
  Users,
  Video,
  VideoOff,
} from "lucide-react";
import type {
  IAgoraRTCClient,
  ICameraVideoTrack,
  IMicrophoneAudioTrack,
  IAgoraRTCRemoteUser,
} from "agora-rtc-sdk-ng";

function RemoteVideoTile({ user }: { user: IAgoraRTCRemoteUser }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [hasVideo, setHasVideo] = useState(Boolean(user.hasVideo));

  useEffect(() => {
    setHasVideo(Boolean(user.hasVideo));
    if (user.hasVideo && containerRef.current && user.videoTrack) {
      user.videoTrack.play(containerRef.current);
    }
  }, [user, user.hasVideo, user.videoTrack]);

  return (
    <div className="relative flex h-full w-full items-center justify-center overflow-hidden rounded-2xl border border-white/10 bg-[#12121e]">
      <div
        ref={containerRef}
        className={`h-full w-full object-cover transition-opacity duration-300 ${
          hasVideo ? "opacity-100" : "opacity-0"
        }`}
      />

      {!hasVideo && (
        <div className="flex flex-col items-center justify-center p-4 text-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-full brand-gradient text-white text-lg font-bold shadow-lg">
            {String(user.uid).slice(-2).toUpperCase()}
          </div>
        </div>
      )}

      <div className="absolute bottom-3 left-3 rounded-xl bg-black/60 px-3 py-1 backdrop-blur-md">
        <span className="font-sans text-xs font-semibold text-white">
          User {String(user.uid).slice(-4)}
        </span>
      </div>
    </div>
  );
}

function GroupCallContent() {
  const params = useParams();
  const searchParams = useSearchParams();
  const router = useRouter();
  const groupId = params.groupId as string;
  const callId = searchParams.get("callId") ?? "";
  const initialType = (searchParams.get("type") as "audio" | "video") ?? "video";

  const localVideoRef = useRef<HTMLDivElement>(null);
  const clientRef = useRef<IAgoraRTCClient | null>(null);
  const localAudioTrackRef = useRef<IMicrophoneAudioTrack | null>(null);
  const localVideoTrackRef = useRef<ICameraVideoTrack | null>(null);

  const [status, setStatus] = useState<"connecting" | "connected" | "ended" | "failed">("connecting");
  const [duration, setDuration] = useState(0);
  const [isMuted, setIsMuted] = useState(false);
  const [isVideoOff, setIsVideoOff] = useState(initialType === "audio");
  const [remoteUsers, setRemoteUsers] = useState<IAgoraRTCRemoteUser[]>([]);
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

        const stored = sessionStorage.getItem(`group_call_${callId}`);
        if (stored) {
          try {
            creds = JSON.parse(stored);
          } catch {
          }
        }

        if (!creds || !creds.token || !creds.appId) {
          const joined = await joinGroupCall(callId);
          creds = {
            token: joined.token,
            appId: joined.appId,
            channel: joined.channel,
            uid: joined.uid,
          };
        }

        if (isCleanedUp) return;

        if (!creds?.token || !creds?.appId || !creds?.channel) {
          setErrorMsg("Group call credentials unavailable");
          setStatus("failed");
          return;
        }

        const AgoraRTC = (await import("agora-rtc-sdk-ng")).default;
        AgoraRTC.setLogLevel(3);

        const client = AgoraRTC.createClient({ mode: "rtc", codec: "vp8" });
        clientRef.current = client;

        client.on("user-published", async (user, mediaType) => {
          await client.subscribe(user, mediaType);
          setRemoteUsers((prev) => {
            const exists = prev.some((u) => u.uid === user.uid);
            if (exists) return prev.map((u) => (u.uid === user.uid ? user : u));
            return [...prev, user];
          });
          if (mediaType === "audio") {
            user.audioTrack?.play();
          }
          setStatus("connected");
          useCallStore.getState().setActiveCall(callId, initialType, {
            groupId,
            title: initialType === "video" ? "Group Video Call" : "Group Voice Call",
          });
        });

        client.on("user-unpublished", (user) => {
          setRemoteUsers((prev) => prev.map((u) => (u.uid === user.uid ? user : u)));
        });

        client.on("user-left", (user) => {
          setRemoteUsers((prev) => {
            const next = prev.filter((u) => u.uid !== user.uid);
            if (next.length === 0) {
              useCallStore.getState().clearActiveCall();
            }
            return next;
          });
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
        setStatus("connected");
      } catch (err) {
        if (!isCleanedUp) {
          setErrorMsg((err as Error).message || "Failed to join group call");
          setStatus("failed");
        }
      }
    }

    init();

    const offEnded = onSocketEvent<Record<string, unknown>>(
      socketEvents.groupCallEnded,
      (data) => {
        const id = String(data?.callId || data?.id || "");
        if (id === callId) {
          setStatus("ended");
          setTimeout(() => {
            router.push(`/groups/${groupId}`);
          }, 1500);
        }
      }
    );

    return () => {
      isCleanedUp = true;
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
      sessionStorage.removeItem(`group_call_${callId}`);
    };
  }, [callId, groupId, initialType, router]);

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

  async function handleLeave() {
    setStatus("ended");
    useCallStore.getState().clearActiveCall();
    emitGroupCallLeave(callId);
    try {
      await leaveGroupCall(callId);
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
    router.push(`/groups/${groupId}`);
  }

  async function handleEndForAll() {
    setStatus("ended");
    useCallStore.getState().clearActiveCall();
    emitGroupCallEnd(callId);
    try {
      await endGroupCall(callId);
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
    router.push(`/groups/${groupId}`);
  }

  const totalParticipants = remoteUsers.length + 1;

  return (
    <div className="relative flex h-dvh w-full flex-col overflow-hidden bg-[#0a0a10] text-white select-none">
      <div className="absolute inset-x-0 top-0 z-30 flex items-center justify-between p-4 bg-gradient-to-b from-black/80 via-black/40 to-transparent">
        <div className="w-10" />

        <div className="flex flex-col items-center">
          <span className="font-sans text-xs font-semibold uppercase tracking-wider text-zinc-300">
            Group {initialType === "video" ? "Video" : "Audio"} Call
          </span>
          <span className="font-sans text-sm font-bold text-white tracking-tight tabular-nums">
            {status === "connected"
              ? formatDuration(duration)
              : status === "connecting"
              ? "Connecting…"
              : status === "failed"
              ? "Connection Failed"
              : "Call Ended"}
          </span>
        </div>

        <div className="flex items-center gap-1.5 rounded-full border border-white/10 bg-white/10 px-3 py-1 text-xs font-semibold text-zinc-300 backdrop-blur-xl">
          <Users className="h-3.5 w-3.5 text-brand-purple" />
          <span className="tabular-nums">{totalParticipants}</span>
        </div>
      </div>

      <div className="flex flex-1 items-center justify-center p-4 pt-20 pb-28">
        {status === "failed" ? (
          <div className="flex flex-col items-center justify-center text-center">
            <h3 className="font-sans text-lg font-bold text-white tracking-tight">
              {errorMsg || "Failed to join group call"}
            </h3>
            <p className="mt-1 text-xs text-zinc-400">
              Please check connection and try again
            </p>
          </div>
        ) : (
          <div
            className={`grid h-full w-full max-w-4xl gap-3 ${
              totalParticipants <= 1
                ? "grid-cols-1"
                : totalParticipants === 2
                ? "grid-cols-1 sm:grid-cols-2"
                : "grid-cols-2"
            }`}
          >
            <div className="relative flex h-full w-full items-center justify-center overflow-hidden rounded-2xl border border-white/15 bg-[#12121e]">
              <div
                ref={localVideoRef}
                className={`h-full w-full object-cover transition-opacity duration-300 ${
                  isVideoOff || initialType === "audio" ? "opacity-0" : "opacity-100"
                }`}
              />

              {(isVideoOff || initialType === "audio") && (
                <div className="flex flex-col items-center justify-center p-4 text-center">
                  <div className="flex h-16 w-16 items-center justify-center rounded-full brand-gradient text-white text-lg font-bold shadow-lg">
                    You
                  </div>
                </div>
              )}

              <div className="absolute bottom-3 left-3 flex items-center gap-2 rounded-xl bg-black/60 px-3 py-1 backdrop-blur-md">
                <span className="font-sans text-xs font-semibold text-white">You</span>
                {isMuted && <MicOff className="h-3 w-3 text-red-400" />}
              </div>
            </div>

            {remoteUsers.map((u) => (
              <RemoteVideoTile key={String(u.uid)} user={u} />
            ))}
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
          onClick={handleLeave}
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

        <button
          type="button"
          onClick={handleEndForAll}
          className="rounded-2xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-xs font-bold text-red-400 transition hover:bg-red-500 hover:text-white"
        >
          End Call
        </button>
      </div>
    </div>
  );
}

export default function GroupCallPage() {
  return (
    <AuthGuard>
      <Suspense>
        <GroupCallContent />
      </Suspense>
    </AuthGuard>
  );
}
