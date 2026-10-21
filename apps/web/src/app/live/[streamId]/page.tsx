"use client";

import { useQuery } from "@tanstack/react-query";
import type {
  IAgoraRTCClient,
  IAgoraRTCRemoteUser,
  ICameraVideoTrack,
  ILocalVideoTrack,
  IMicrophoneAudioTrack,
} from "agora-rtc-sdk-ng";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { endStream, getStream, getStreamToken, uploadStreamChatFile } from "@/lib/api/streams";
import { getGiftCatalog } from "@/lib/api/misc";
import { emitSocketAck, emitSocket, onSocketEvent, socketEvents } from "@/lib/socket";
import { useAuthStore } from "@/lib/stores";
import { cn } from "@/lib/utils";
import { LiveChatOpenButton, LiveChatPanel, type LiveChatMessage } from "@/components/live-chat-panel";
import { LiveGiftSheet } from "@/components/live-gift-sheet";
import { LiveGiftHistorySheet } from "@/components/live-gift-history-sheet";
import { LiveInviteSheet } from "@/components/live-invite-sheet";
import {
  captionTextForRole,
  emitTranscriptChunk,
  parseAgoraCaptionPayload,
  startHostSpeechCaptions,
  normalizeCaptionPayload,
} from "@/lib/live-captions";
import {
  FlipHorizontal2,
  Gift,
  Languages,
  Mic,
  MicOff,
  Radio,
  ScreenShare,
  ScreenShareOff,
  Share2,
  UserPlus,
  Users,
  Video as VideoIcon,
  VideoOff,
  X,
} from "lucide-react";

function formatElapsed(totalSec: number) {
  const s = Math.max(0, Math.floor(totalSec));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${String(m).padStart(2, "0")}:${String(r).padStart(2, "0")}`;
}

function RemoteLiveVideoTile({
  user,
  isHost,
}: {
  user: IAgoraRTCRemoteUser;
  isHost?: boolean;
}) {
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
        className={cn(
          "h-full w-full object-cover transition-opacity duration-300",
          hasVideo ? "opacity-100" : "opacity-0"
        )}
      />

      {!hasVideo && (
        <div className="flex flex-col items-center justify-center p-4 text-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-full brand-gradient text-white text-lg font-bold shadow-lg">
            {isHost ? "Host" : "Co-host"}
          </div>
          <p className="mt-2 text-xs font-semibold text-white/80">
            {isHost ? "Host camera off" : "Co-host camera off"}
          </p>
        </div>
      )}

      <div className="absolute bottom-2.5 left-2.5 flex items-center gap-1.5 rounded-xl bg-black/60 px-2.5 py-1 backdrop-blur-md">
        <span className="font-sans text-[11px] font-bold text-white">
          {isHost ? "Host" : `Co-host ${String(user.uid).slice(-4)}`}
        </span>
        {user.hasAudio === false && (
          <MicOff className="h-3 w-3 text-red-400" />
        )}
      </div>
    </div>
  );
}

function parseChatMessage(d: unknown, streamId: string): LiveChatMessage | null {
  let raw: unknown = d;
  if (typeof raw === "string") {
    try {
      raw = JSON.parse(raw);
    } catch {
      return null;
    }
  }
  if (!raw || typeof raw !== "object") return null;
  const o = raw as Record<string, unknown>;
  const nested = (
    o.comment && typeof o.comment === "object"
      ? o.comment
      : o.message && typeof o.message === "object"
      ? o.message
      : o.data && typeof o.data === "object"
      ? o.data
      : o.payload && typeof o.payload === "object"
      ? o.payload
      : o
  ) as Record<string, unknown>;
  const sid = String(o.streamId ?? nested.streamId ?? "");
  if (sid && sid !== streamId) return null;
  const content = String(nested.content ?? nested.text ?? nested.body ?? o.content ?? "");
  const mediaUrl = String(nested.mediaUrl ?? nested.url ?? nested.fileUrl ?? o.mediaUrl ?? "");
  if (!content && !mediaUrl) return null;
  const user = (
    nested.user && typeof nested.user === "object"
      ? nested.user
      : nested.author && typeof nested.author === "object"
      ? nested.author
      : nested.sender && typeof nested.sender === "object"
      ? nested.sender
      : {}
  ) as Record<string, unknown>;
  return {
    content,
    userId: String(nested.userId ?? nested.senderId ?? user.id ?? user._id ?? ""),
    userName: String(
      nested.userName ??
        nested.senderName ??
        nested.username ??
        user.username ??
        user.displayName ??
        "Viewer"
    ),
    mediaUrl: mediaUrl || undefined,
    mediaType: nested.mediaType ? String(nested.mediaType) : undefined,
    fileName: String(nested.fileName ?? nested.filename ?? "") || undefined,
  };
}

function remoteScreenShareActive(users: IAgoraRTCRemoteUser[]) {
  return users.some((user) => {
    const track = user.videoTrack?.getMediaStreamTrack?.();
    if (!track) return false;
    const settings = track.getSettings() as MediaTrackSettings & { displaySurface?: string };
    if (settings.displaySurface) return true;
    const label = (track.label || "").toLowerCase();
    return label.includes("screen") || label.includes("window") || label.includes("display");
  });
}
function parseViewerCount(d: unknown): number | null {
  if (typeof d === "number" && Number.isFinite(d)) return d;
  if (Array.isArray(d)) return d.length;
  if (!d || typeof d !== "object") return null;
  const o = d as Record<string, unknown>;
  for (const key of ["count", "viewerCount", "viewersCount", "total"]) {
    const value = o[key];
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string" && Number.isFinite(Number(value))) return Number(value);
  }
  for (const key of ["viewers", "users", "items", "docs"]) {
    const value = o[key];
    if (Array.isArray(value)) return value.length;
  }
  return null;
}

function LiveStreamContent() {
  const params = useParams();
  const searchParams = useSearchParams();
  const router = useRouter();

  const streamId = params.streamId as string;
  const urlRole = searchParams.get("role");
  const user = useAuthStore((s) => s.user);

  const localVideoRef = useRef<HTMLDivElement>(null);
  const cameraDevicesRef = useRef<{ deviceId: string }[]>([]);
  const cameraIndexRef = useRef(0);
  const [canFlipCamera, setCanFlipCamera] = useState(false);
  const attachRef = useRef<HTMLInputElement>(null);
  const clientRef = useRef<IAgoraRTCClient | null>(null);
  const localAudioTrackRef = useRef<IMicrophoneAudioTrack | null>(null);
  const localVideoTrackRef = useRef<ICameraVideoTrack | null>(null);
  const screenTrackRef = useRef<ILocalVideoTrack | null>(null);

  const [viewerCount, setViewerCount] = useState(0);
  const [chatInput, setChatInput] = useState("");
  const [messages, setMessages] = useState<LiveChatMessage[]>([]);
  const [joined, setJoined] = useState(false);
  const [remoteUsers, setRemoteUsers] = useState<IAgoraRTCRemoteUser[]>([]);
  const [chatMode, setChatMode] = useState<"open" | "expanded" | "closed">("closed");
  const [giftOpen, setGiftOpen] = useState(false);
  const [giftHistoryOpen, setGiftHistoryOpen] = useState(false);
  const [inviteOpen, setInviteOpen] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [shareHint, setShareHint] = useState("");
  const [elapsedSec, setElapsedSec] = useState(0);
  const [captionsOn, setCaptionsOn] = useState(true);

  const [isMuted, setIsMuted] = useState(false);
  const [isVideoOff, setIsVideoOff] = useState(false);
  const [isScreenSharing, setIsScreenSharing] = useState(false);
  const [captionText, setCaptionText] = useState("");
  const captionClearRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const showCaption = useCallback((text: string) => {
    if (!text || !captionsOn) return;
    setCaptionText(text);
    if (captionClearRef.current) clearTimeout(captionClearRef.current);
    captionClearRef.current = setTimeout(() => {
      setCaptionText("");
      captionClearRef.current = null;
    }, 10000);
  }, [captionsOn]);

  const { data: stream } = useQuery({
    queryKey: ["stream", streamId],
    queryFn: () => getStream(streamId),
    refetchInterval: 8000,
  });

  const { data: giftCatalog = [] } = useQuery({
    queryKey: ["gift-catalog"],
    queryFn: getGiftCatalog,
    staleTime: 60_000,
  });

  const streamHostId = stream?.hostId;
  const isHost = Boolean(stream && user && streamHostId === user.id);
  const isCohost = urlRole === "cohost";
  const isBroadcaster = isHost || isCohost;
  const isPrivateStream = Boolean(stream?.isPrivate);
  const agoraRole: "host" | "audience" = isBroadcaster ? "host" : "audience";
  const showGift = Boolean(user && !isHost && giftCatalog.length);

  useEffect(() => {
    if (window.matchMedia("(min-width: 1024px)").matches) setChatMode("open");
  }, []);

  useEffect(() => {
    if (typeof stream?.viewerCount === "number") {
      setViewerCount((n) => Math.max(n, stream.viewerCount || 0));
    }
  }, [stream?.viewerCount]);

  useEffect(() => {
    if (!joined) return;
    const started = Date.now();
    setElapsedSec(0);
    const id = window.setInterval(() => {
      setElapsedSec(Math.floor((Date.now() - started) / 1000));
    }, 1000);
    return () => window.clearInterval(id);
  }, [joined]);

  useEffect(() => {
    if (!captionsOn) setCaptionText("");
  }, [captionsOn]);

  async function shareLive() {
    const title = stream?.title?.trim() || "Live stream";
    const link = `${window.location.origin}/live/${streamId}`;
    const text = `Watch "${title}" live on Xlive\n${link}`;
    try {
      if (navigator.share) {
        await navigator.share({ title, text, url: link });
      } else {
        await navigator.clipboard.writeText(text);
        setShareHint("Link copied");
        window.setTimeout(() => setShareHint(""), 1600);
      }
    } catch {
      try {
        await navigator.clipboard.writeText(link);
        setShareHint("Link copied");
        window.setTimeout(() => setShareHint(""), 1600);
      } catch {
        setShareHint("Share failed");
        window.setTimeout(() => setShareHint(""), 1600);
      }
    }
  }

  useEffect(() => {
    if (!stream) return;
    let isCleanedUp = false;

    async function initAgora() {
      try {
        const tokenData = await getStreamToken(streamId, agoraRole);
        const AgoraRTC = (await import("agora-rtc-sdk-ng")).default;
        AgoraRTC.setLogLevel(3);

        const client = AgoraRTC.createClient({ mode: "live", codec: "vp8" });
        clientRef.current = client;

        await client.setClientRole(agoraRole);

        client.on("user-published", async (remoteUser, mediaType) => {
          await client.subscribe(remoteUser, mediaType);
          if (isCleanedUp) return;

          if (mediaType === "audio") {
            remoteUser.audioTrack?.play();
          }

          setRemoteUsers((prev) => {
            const exists = prev.some((u) => u.uid === remoteUser.uid);
            if (exists) {
              return prev.map((u) => (u.uid === remoteUser.uid ? remoteUser : u));
            }
            return [...prev, remoteUser];
          });
        });

        client.on("user-unpublished", (remoteUser, mediaType) => {
          if (mediaType === "video") {
            setRemoteUsers((prev) =>
              prev.map((u) => (u.uid === remoteUser.uid ? remoteUser : u))
            );
          }
        });

        client.on("user-left", (remoteUser) => {
          setRemoteUsers((prev) => prev.filter((u) => u.uid !== remoteUser.uid));
        });

        client.on("stream-message", (_uid, payload) => {
          if (!isHost) return;
          const parsed = parseAgoraCaptionPayload(payload);
          if (!parsed?.text) return;
          const shown = captionTextForRole(parsed, true);
          if (shown) showCaption(shown);
          emitTranscriptChunk(streamId, parsed);
        });

        const appId = tokenData.appId || "";
        const channel = tokenData.channelName || tokenData.channel || streamId;
        await client.join(appId, channel, tokenData.token, tokenData.uid ?? null);

        if (isBroadcaster) {
          const [mic, cam] = await AgoraRTC.createMicrophoneAndCameraTracks();
          if (isCleanedUp) {
            mic.stop();
            mic.close();
            cam.stop();
            cam.close();
            return;
          }
          localAudioTrackRef.current = mic;
          localVideoTrackRef.current = cam;

          await client.publish([mic, cam]);

          if (localVideoRef.current) {
            cam.play(localVideoRef.current);
          }

          try {
            const AgoraRTCDevices = (await import("agora-rtc-sdk-ng")).default;
            const devices = await AgoraRTCDevices.getCameras();
            cameraDevicesRef.current = devices.filter((d) => d.deviceId);
            cameraIndexRef.current = 0;
            if (!isCleanedUp) setCanFlipCamera(cameraDevicesRef.current.length > 1);
          } catch {
            if (!isCleanedUp) setCanFlipCamera(false);
          }
        }

        if (!isCleanedUp) {
          setJoined(true);
          setViewerCount((n) => Math.max(n, agoraRole === "audience" ? 1 : n));
        }
      } catch (err) {
        console.error("Agora live join failed", err);
      }
    }

    initAgora();
    emitSocketAck("join_stream", { streamId })
      .then((res) => {
        const n = parseViewerCount(res);
        if (n != null) setViewerCount((c) => Math.max(c, n));
      })
      .catch(() => {});

    const applyViewers = (d: unknown) => {
      const n = parseViewerCount(d);
      if (n != null) setViewerCount(n);
    };

    const offs = [
      onSocketEvent(socketEvents.viewerCount, applyViewers),
      onSocketEvent("viewer_count", applyViewers),
      onSocketEvent("stream_viewer_count", applyViewers),
      onSocketEvent(socketEvents.streamViewers, applyViewers),
      onSocketEvent<unknown>(socketEvents.streamChat, (d) => {
        const parsed = parseChatMessage(d, streamId);
        if (parsed) setMessages((m) => [...m, parsed]);
      }),
      onSocketEvent(socketEvents.streamEnded, () => {
        router.push(`/live/${streamId}/summary`);
      }),
      onSocketEvent<unknown>(socketEvents.transcript, (raw) => {
        const chunk = normalizeCaptionPayload(raw);
        if (!chunk) return;
        if (chunk.streamId && chunk.streamId !== streamId) return;
        const shown = captionTextForRole(chunk, isHost);
        if (shown) showCaption(shown);
      }),
      onSocketEvent<unknown>(socketEvents.transcriptHistory, (raw) => {
        const payload = raw as Record<string, unknown> | null;
        if (payload?.streamId && String(payload.streamId) !== streamId) return;
        const items = Array.isArray(payload?.items)
          ? payload.items
          : Array.isArray(payload?.docs)
          ? payload.docs
          : Array.isArray(payload?.transcripts)
          ? payload.transcripts
          : [];
        const last = items.length ? items[items.length - 1] : null;
        const chunk = normalizeCaptionPayload(last);
        if (!chunk) return;
        const shown = captionTextForRole(chunk, isHost);
        if (shown) showCaption(shown);
      }),
    ];

    return () => {
      isCleanedUp = true;
      offs.forEach((o) => o());
      emitSocketAck("leave_stream", { streamId }).catch(() => {});

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
      if (screenTrackRef.current) {
        screenTrackRef.current.stop();
        screenTrackRef.current.close();
        screenTrackRef.current = null;
      }
      if (clientRef.current) {
        clientRef.current.leave().catch(() => {});
        clientRef.current = null;
      }
    };
  }, [streamId, agoraRole, isBroadcaster, isHost, stream, router, showCaption]);

  useEffect(() => {
    return () => {
      if (captionClearRef.current) clearTimeout(captionClearRef.current);
    };
  }, []);

  useEffect(() => {
    if (!joined || !isHost) return;
    if (!stream?.captionsEnabled && !stream?.saveEnabled) return;
    const stop = startHostSpeechCaptions({
      lang: user?.language,
      onChunk: (chunk) => {
        const shown = captionTextForRole(chunk, true);
        if (shown) showCaption(shown);
        emitTranscriptChunk(streamId, chunk);
      },
    });
    return stop;
  }, [joined, isHost, stream?.captionsEnabled, stream?.saveEnabled, streamId, user?.language, showCaption]);

  async function toggleMute() {
    if (!localAudioTrackRef.current) return;
    const next = !isMuted;
    await localAudioTrackRef.current.setEnabled(!next);
    setIsMuted(next);
  }

  async function toggleVideo() {
    if (isScreenSharing) return;
    if (!localVideoTrackRef.current) return;
    const next = !isVideoOff;
    await localVideoTrackRef.current.setEnabled(!next);
    setIsVideoOff(next);
  }

  async function flipCamera() {
    const track = localVideoTrackRef.current;
    const devices = cameraDevicesRef.current;
    if (!track || devices.length < 2 || isScreenSharing || isVideoOff) return;
    cameraIndexRef.current = (cameraIndexRef.current + 1) % devices.length;
    try {
      await track.setDevice(devices[cameraIndexRef.current].deviceId);
      if (localVideoRef.current) track.play(localVideoRef.current);
    } catch {}
  }

  async function stopScreenShare() {
    const client = clientRef.current;
    const screen = screenTrackRef.current;
    if (screen) {
      try {
        await client?.unpublish(screen);
      } catch {}
      screen.stop();
      screen.close();
      screenTrackRef.current = null;
    }
    setIsScreenSharing(false);
    if (client && localVideoTrackRef.current) {
      try {
        await client.publish(localVideoTrackRef.current);
      } catch {}
      if (localVideoRef.current) localVideoTrackRef.current.play(localVideoRef.current);
    }
  }

  async function toggleScreenShare() {
    if (!isPrivateStream || !isBroadcaster) return;
    const client = clientRef.current;
    if (!client) return;
    if (screenTrackRef.current) {
      await stopScreenShare();
      return;
    }
    if (remoteScreenShareActive(remoteUsers)) return;
    try {
      const AgoraRTC = (await import("agora-rtc-sdk-ng")).default;
      const created = await AgoraRTC.createScreenVideoTrack({ encoderConfig: "1080p_1" }, "disable");
      const track = Array.isArray(created) ? created[0] : created;
      if (localVideoTrackRef.current) {
        try {
          await client.unpublish(localVideoTrackRef.current);
        } catch {}
        localVideoTrackRef.current.stop();
      }
      await client.publish(track);
      if (localVideoRef.current) track.play(localVideoRef.current);
      track.on("track-ended", () => {
        void stopScreenShare();
      });
      screenTrackRef.current = track;
      setIsScreenSharing(true);
    } catch (err) {
      console.error("Screen share failed", err);
    }
  }

  async function handleEnd() {
    if (!confirm("Are you sure you want to end this live stream?")) return;
    try {
      await endStream(streamId);
    } catch {}
    router.push(`/live/${streamId}/summary`);
  }

  function handleLeave() {
    router.push("/live");
  }

  function sendChat() {
    if (!chatInput.trim()) return;
    const content = chatInput.trim();
    emitSocket("stream_chat_message", { streamId, content });
    setMessages((m) => [...m, { content, userName: user?.username ? `@${user.username}` : "@you" }]);
    setChatInput("");
  }

  async function handleAttach(file: File) {
    const mediaType = file.type.startsWith("image/")
      ? "image"
      : file.type.startsWith("video/")
      ? "video"
      : "document";
    setUploading(true);
    try {
      const uploaded = await uploadStreamChatFile(streamId, file, mediaType, chatInput.trim() || file.name);
      const content = uploaded.content || file.name;
      emitSocket("stream_chat_message", {
        streamId,
        content,
        mediaUrl: uploaded.mediaUrl,
        mediaType: uploaded.mediaType,
        fileName: uploaded.fileName,
      });
      setMessages((m) => [
        ...m,
        {
          content,
          userName: user?.username ? `@${user.username}` : "@you",
          mediaUrl: uploaded.mediaUrl || undefined,
          mediaType: uploaded.mediaType,
          fileName: uploaded.fileName,
        },
      ]);
      setChatInput("");
    } catch (err) {
      console.error("Live chat upload failed", err);
    } finally {
      setUploading(false);
    }
  }

  const totalBroadcasters = (isBroadcaster ? 1 : 0) + remoteUsers.length;

  const chatVisible = chatMode !== "closed";
  const chatExpanded = chatMode === "expanded";
  const chatPanel = (
    <LiveChatPanel
      title="Live chat"
      messages={messages}
      chatInput={chatInput}
      onChatInput={setChatInput}
      onSend={sendChat}
      onAttach={() => attachRef.current?.click()}
      uploading={uploading}
      expanded={chatExpanded}
      overlay={chatExpanded || chatMode === "open"}
      onToggleExpand={() => setChatMode(chatExpanded ? "open" : "expanded")}
      onClose={() => setChatMode("closed")}
    />
  );

  return (
    <div className="relative flex h-full min-h-0 flex-col overflow-hidden bg-black text-white lg:flex-row">
      <input
        ref={attachRef}
        type="file"
        className="hidden"
        accept="image/*,.pdf,.doc,.docx,.txt,.zip,.csv,.xls,.xlsx"
        onChange={(e) => {
          const file = e.target.files?.[0];
          e.target.value = "";
          if (file) void handleAttach(file);
        }}
      />
      <LiveGiftSheet streamId={streamId} open={giftOpen} onClose={() => setGiftOpen(false)} />
      <LiveGiftHistorySheet streamId={streamId} open={giftHistoryOpen} onClose={() => setGiftHistoryOpen(false)} />
      {streamHostId ? (
        <LiveInviteSheet
          streamId={streamId}
          hostUserId={streamHostId}
          allowCohost={isPrivateStream}
          open={inviteOpen}
          onClose={() => setInviteOpen(false)}
        />
      ) : null}

      <div className="relative min-h-0 flex-1 p-2 md:p-3">
        {!joined ? (
          <div className="absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 bg-neutral-950">
            <div className="h-10 w-10 animate-pulse rounded-full brand-gradient" />
            <p className="font-sans text-xs text-white/70">Connecting to live stream…</p>
          </div>
        ) : null}

        <div className="absolute inset-x-0 top-0 z-30 flex items-center justify-between p-4 bg-gradient-to-b from-black/80 via-black/40 to-transparent">
          <div className="flex items-center gap-2">
            <span className="flex items-center gap-1.5 rounded-full bg-red-600 px-3 py-1 font-sans text-xs font-bold text-white shadow-lg shadow-red-600/30">
              <Radio className="h-3 w-3 animate-pulse" /> LIVE
            </span>
            <span className="flex items-center gap-1.5 rounded-full bg-black/60 px-3 py-1 font-sans text-xs font-semibold text-white/90 backdrop-blur-md">
              <Users className="h-3.5 w-3.5" /> {viewerCount}
            </span>
            {joined ? (
              <span className="rounded-full bg-black/60 px-3 py-1 font-sans text-xs font-semibold tabular-nums text-white/90 backdrop-blur-md">
                {formatElapsed(elapsedSec)}
              </span>
            ) : null}
            {isBroadcaster && (
              <span className="rounded-full bg-brand-purple/30 border border-brand-purple/40 px-2.5 py-0.5 font-sans text-[11px] font-bold text-brand-purple">
                {isHost ? "Host" : "Co-Host"}
              </span>
            )}
            {stream?.title ? (
              <span className="hidden max-w-[40vw] truncate rounded-full bg-black/50 px-3 py-1 font-sans text-xs font-semibold text-white/90 sm:inline">
                {stream.title}
              </span>
            ) : null}
          </div>

          <div className="flex items-center gap-2">
            {(stream?.captionsEnabled || stream?.saveEnabled) ? (
              <button
                type="button"
                onClick={() => setCaptionsOn((v) => !v)}
                className={cn(
                  "flex h-9 w-9 items-center justify-center rounded-full backdrop-blur-md transition active:scale-95",
                  captionsOn ? "bg-brand-purple/30 text-white" : "bg-black/60 text-white/70 hover:bg-black/80"
                )}
                title={captionsOn ? "Hide captions" : "Show captions"}
                aria-label="AI Translator"
              >
                <Languages className="h-4 w-4" />
              </button>
            ) : null}
            <button
              type="button"
              onClick={() => void shareLive()}
              className="flex h-9 w-9 items-center justify-center rounded-full bg-black/60 text-white backdrop-blur-md transition hover:bg-black/80 active:scale-95"
              title="Share stream"
              aria-label="Share stream"
            >
              <Share2 className="h-4 w-4" />
            </button>
            {shareHint ? (
              <span className="hidden rounded-full bg-black/70 px-2 py-1 text-[10px] font-semibold text-white sm:inline">
                {shareHint}
              </span>
            ) : null}
            {isHost ? (
              <button
                type="button"
                onClick={handleEnd}
                className="rounded-2xl bg-red-600 px-3.5 py-1.5 font-sans text-xs font-bold text-white shadow-lg transition hover:bg-red-700 active:scale-95"
              >
                End Stream
              </button>
            ) : isCohost ? (
              <button
                type="button"
                onClick={handleLeave}
                className="rounded-2xl border border-red-500/40 bg-red-500/20 px-3 py-1.5 font-sans text-xs font-bold text-red-300 transition hover:bg-red-500/30 active:scale-95"
              >
                Leave
              </button>
            ) : (
              <button
                type="button"
                onClick={() => router.push("/live")}
                className="flex h-9 w-9 items-center justify-center rounded-full bg-black/60 text-white backdrop-blur-md transition hover:bg-black/80 active:scale-95"
              >
                <X className="h-4 w-4" />
              </button>
            )}
            {showGift ? (
              <button
                type="button"
                onClick={() => setGiftOpen(true)}
                className="flex h-9 w-9 items-center justify-center rounded-full bg-amber-400/20 text-amber-300 backdrop-blur-md"
                title="Gift the host"
              >
                <Gift className="h-4 w-4" />
              </button>
            ) : null}
          </div>
        </div>

        <div
          className={cn(
            "h-full w-full grid gap-2 overflow-hidden rounded-3xl",
            totalBroadcasters <= 1
              ? "grid-cols-1"
              : totalBroadcasters === 2
              ? "grid-cols-1 sm:grid-cols-2"
              : "grid-cols-2"
          )}
        >
          {isBroadcaster && (
            <div className="relative flex h-full w-full items-center justify-center overflow-hidden rounded-2xl border border-white/10 bg-[#12121e]">
              <div
                ref={localVideoRef}
                className={cn(
                  "h-full w-full object-cover transition-opacity duration-300",
                  isVideoOff ? "opacity-0" : "opacity-100"
                )}
              />

              {isVideoOff && (
                <div className="flex flex-col items-center justify-center p-4 text-center">
                  <div className="flex h-16 w-16 items-center justify-center rounded-full brand-gradient text-white text-lg font-bold shadow-lg">
                    You
                  </div>
                  <p className="mt-2 text-xs font-semibold text-white/80">Camera turned off</p>
                </div>
              )}

              <div className="absolute bottom-2.5 left-2.5 flex items-center gap-1.5 rounded-xl bg-black/60 px-2.5 py-1 backdrop-blur-md">
                <span className="font-sans text-[11px] font-bold text-white">
                  You ({isHost ? "Host" : "Co-host"})
                </span>
                {isMuted && <MicOff className="h-3 w-3 text-red-400" />}
              </div>
            </div>
          )}

          {remoteUsers.map((u) => (
            <RemoteLiveVideoTile
              key={String(u.uid)}
              user={u}
              isHost={!isHost && remoteUsers.length > 0 && remoteUsers[0].uid === u.uid}
            />
          ))}

          {!isBroadcaster && remoteUsers.length === 0 && (
            <div className="flex h-full w-full flex-col items-center justify-center rounded-2xl border border-white/10 bg-[#12121e] p-6 text-center">
              <div className="flex h-16 w-16 items-center justify-center rounded-full brand-gradient text-white shadow-lg">
                <Radio className="h-7 w-7 animate-pulse" />
              </div>
              <h3 className="mt-4 font-sans text-base font-bold text-white">Waiting for video stream…</h3>
              <p className="mt-1 text-xs text-zinc-400">The host is preparing to broadcast</p>
            </div>
          )}
        </div>

        {captionText ? (
          <div className="pointer-events-none absolute inset-x-0 bottom-[7.5rem] z-30 flex justify-center px-4 md:bottom-28">
            <p className="max-w-[min(92%,520px)] rounded-xl bg-black/75 px-4 py-2.5 text-center font-sans text-sm font-semibold leading-snug text-white shadow-lg backdrop-blur-md">
              {captionText}
            </p>
          </div>
        ) : null}

        <div className="absolute bottom-[88px] right-4 z-30 flex flex-col items-end gap-2 md:bottom-6">
          {chatMode === "closed" ? <LiveChatOpenButton onClick={() => setChatMode("open")} /> : null}
        </div>

        {isBroadcaster && (
          <div className="absolute bottom-[88px] left-1/2 z-30 flex -translate-x-1/2 items-center gap-2 rounded-2xl border border-white/10 bg-black/75 px-3 py-2 backdrop-blur-xl md:bottom-6 md:gap-3 md:px-4">
            {isHost ? (
              <button
                type="button"
                onClick={() => setInviteOpen(true)}
                className="flex h-11 w-11 items-center justify-center rounded-xl border border-white/10 bg-white/10 text-white transition hover:bg-white/20 active:scale-95"
                aria-label="Invite people"
                title="Invite people"
              >
                <UserPlus className="h-5 w-5" />
              </button>
            ) : null}
            <button
              type="button"
              onClick={toggleMute}
              className={cn(
                "flex h-11 w-11 items-center justify-center rounded-xl border transition active:scale-95",
                isMuted
                  ? "border-red-500/40 bg-red-500/20 text-red-400"
                  : "border-white/10 bg-white/10 text-white hover:bg-white/20"
              )}
            >
              {isMuted ? <MicOff className="h-5 w-5" /> : <Mic className="h-5 w-5" />}
            </button>
            <button
              type="button"
              onClick={toggleVideo}
              disabled={isScreenSharing}
              className={cn(
                "flex h-11 w-11 items-center justify-center rounded-xl border transition active:scale-95",
                isVideoOff
                  ? "border-red-500/40 bg-red-500/20 text-red-400"
                  : "border-white/10 bg-white/10 text-white hover:bg-white/20",
                isScreenSharing && "opacity-40"
              )}
            >
              {isVideoOff ? <VideoOff className="h-5 w-5" /> : <VideoIcon className="h-5 w-5" />}
            </button>
            {canFlipCamera ? (
              <button
                type="button"
                onClick={() => void flipCamera()}
                disabled={isScreenSharing || isVideoOff}
                className={cn(
                  "flex h-11 w-11 items-center justify-center rounded-xl border border-white/10 bg-white/10 text-white transition hover:bg-white/20 active:scale-95",
                  (isScreenSharing || isVideoOff) && "opacity-40"
                )}
                aria-label="Flip camera"
              >
                <FlipHorizontal2 className="h-5 w-5" />
              </button>
            ) : null}
            {isPrivateStream ? (
              <button
                type="button"
                onClick={() => void toggleScreenShare()}
                disabled={!isScreenSharing && remoteScreenShareActive(remoteUsers)}
                className={cn(
                  "flex h-11 w-11 items-center justify-center rounded-xl border transition active:scale-95",
                  isScreenSharing
                    ? "border-sky-400/40 bg-sky-500/20 text-sky-300"
                    : "border-white/10 bg-white/10 text-white hover:bg-white/20",
                  !isScreenSharing && remoteScreenShareActive(remoteUsers) && "opacity-40"
                )}
              >
                {isScreenSharing ? <ScreenShareOff className="h-5 w-5" /> : <ScreenShare className="h-5 w-5" />}
              </button>
            ) : null}
            {isHost ? (
              <button
                type="button"
                onClick={() => setGiftHistoryOpen(true)}
                className="flex h-11 w-11 items-center justify-center rounded-xl border border-white/10 bg-white/10 text-amber-300 transition hover:bg-white/20 active:scale-95"
                aria-label="Gift history"
                title="Gift history"
              >
                <Gift className="h-5 w-5" />
              </button>
            ) : null}
          </div>
        )}
      </div>

      {chatVisible && chatExpanded ? (
        <div className="fixed inset-x-0 top-0 bottom-[70px] z-50 flex bg-black/70 md:bottom-0 lg:inset-0 lg:bg-black/80">
          <button type="button" className="hidden flex-1 lg:block" onClick={() => setChatMode("open")} />
          <div className="mt-[10vh] flex min-h-0 w-full flex-1 flex-col lg:mt-0 lg:max-w-xl">{chatPanel}</div>
        </div>
      ) : null}

      {chatVisible && !chatExpanded ? (
        <div className="fixed inset-x-0 top-[12%] bottom-[70px] z-50 md:bottom-0 lg:static lg:inset-auto lg:bottom-auto lg:top-auto lg:z-20 lg:h-full lg:w-[360px] lg:shrink-0 lg:border-l lg:border-white/10">
          {chatPanel}
        </div>
      ) : null}
    </div>
  );
}

export default function LiveStreamPage() {
  return (
    <AuthGuard>
      <Suspense
        fallback={
          <div className="flex h-dvh items-center justify-center bg-black">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        }
      >
        <LiveStreamContent />
      </Suspense>
    </AuthGuard>
  );
}
