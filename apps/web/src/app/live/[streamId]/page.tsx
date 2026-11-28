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
import { endStream, getStream, getStreamToken, listStreamChat, uploadStreamChatFile } from "@/lib/api/streams";
import {
  getGiftCatalog,
  getWallet,
  joinAckSkipsBilling,
  lookupMySubscriptions,
} from "@/lib/api/misc";
import {
  emitSocketAck,
  emitSocket,
  onSocketEvent,
  socketEvents,
  grantTalkBack,
  revokeTalkBack,
  muteStreamViewer,
  unmuteStreamViewer,
  removeStreamViewer,
  requestStreamViewers,
} from "@/lib/socket";
import { useAuthStore } from "@/lib/stores";
import { cloudinaryUrl, cn } from "@/lib/utils";
import { LiveChatOpenButton, LiveChatPanel, type LiveChatMessage } from "@/components/live-chat-panel";
import { LiveGiftSheet } from "@/components/live-gift-sheet";
import { LiveGiftHistorySheet } from "@/components/live-gift-history-sheet";
import { LiveInviteSheet } from "@/components/live-invite-sheet";
import {
  LiveManageViewersSheet,
  type LiveViewerRow,
} from "@/components/live-manage-viewers-sheet";
import {
  captionTextForRole,
  emitTranscriptChunk,
  parseAgoraCaptionPayload,
  startHostSpeechCaptions,
  normalizeCaptionPayload,
  type CaptionChunk,
} from "@/lib/live-captions";
import { normalizeLiveLang } from "@/lib/live-languages";
import { LIVE_SEGMENT_MIN } from "@/lib/live-segments";
import {
  setRemoteAudioDucked,
  speakLiveTranslation,
  stopLiveSpeech,
  translateLiveText,
  unlockLiveSpeech,
} from "@/lib/live-translate";
import { resolveGiftSocketEvent } from "@/lib/gifts";
import {
  AudioLines,
  FlipHorizontal2,
  Gift,
  Headphones,
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

type GiftToast = {
  id: string;
  text: string;
};

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

function chatMessageKey(m: LiveChatMessage) {
  return `${m.userId || ""}|${m.userName || ""}|${m.content}|${m.mediaUrl || ""}`;
}

function mergeChatHistory(history: LiveChatMessage[], live: LiveChatMessage[]) {
  const seen = new Set(history.map(chatMessageKey));
  const extras = live.filter((m) => {
    const key = chatMessageKey(m);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
  return [...history, ...extras];
}

function appendChatUnique(prev: LiveChatMessage[], next: LiveChatMessage) {
  const key = chatMessageKey(next);
  if (prev.some((m) => chatMessageKey(m) === key)) return prev;
  return [...prev, next];
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

function parseViewerRows(d: unknown): LiveViewerRow[] {
  if (!d || typeof d !== "object") return [];
  const o = d as Record<string, unknown>;
  const raw = o.viewers ?? o.users ?? o.items ?? o.docs;
  if (!Array.isArray(raw)) return [];
  const rows: LiveViewerRow[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const map = item as Record<string, unknown>;
    const user =
      (map.user && typeof map.user === "object" ? map.user : null) as Record<string, unknown> | null;
    const id = String(map.userId ?? map.id ?? user?.id ?? user?._id ?? "");
    if (!id) continue;
    rows.push({
      id,
      name: String(
        map.displayName ?? map.username ?? user?.displayName ?? user?.username ?? "Viewer"
      ),
      avatarUrl: (map.avatarUrl ?? user?.avatarUrl ?? user?.avatar) as string | undefined,
      muted: map.muted === true || map.isMuted === true,
      talkBack:
        map.talkBack === true || map.hasTalkBack === true || map.talkBackGranted === true,
    });
  }
  return rows;
}

function eventUserId(d: unknown): string {
  if (!d || typeof d !== "object") return "";
  const o = d as Record<string, unknown>;
  return String(o.userId ?? o.id ?? "");
}

function eventStreamId(d: unknown): string {
  if (!d || typeof d !== "object") return "";
  return String((d as Record<string, unknown>).streamId ?? "");
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
  const [joinError, setJoinError] = useState("");
  const [joinAttempt, setJoinAttempt] = useState(0);
  const [remoteUsers, setRemoteUsers] = useState<IAgoraRTCRemoteUser[]>([]);
  const [chatMode, setChatMode] = useState<"open" | "expanded" | "closed">("closed");
  const [giftOpen, setGiftOpen] = useState(false);
  const [giftHistoryOpen, setGiftHistoryOpen] = useState(false);
  const [inviteOpen, setInviteOpen] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [shareHint, setShareHint] = useState("");
  const [elapsedSec, setElapsedSec] = useState(0);
  const [captionsOn, setCaptionsOn] = useState(true);
  const [hearTranslate, setHearTranslate] = useState(true);
  const hearTranslateRef = useRef(true);
  const translatorLiveRef = useRef(false);
  const remoteUsersRef = useRef<IAgoraRTCRemoteUser[]>([]);
  const lastSpokenSegmentRef = useRef("");
  const lastGoodCaptionRef = useRef("");
  const interimTextRef = useRef("");
  const interimTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const translateQueueRef = useRef<Array<{ text: string; speak: boolean }>>([]);
  const translatePumpRef = useRef(false);
  const targetLangRef = useRef("en");
  const [giftToasts, setGiftToasts] = useState<GiftToast[]>([]);
  const giftToastSeqRef = useRef(0);

  const [isMuted, setIsMuted] = useState(false);
  const [isVideoOff, setIsVideoOff] = useState(false);
  const [isScreenSharing, setIsScreenSharing] = useState(false);
  const [captionText, setCaptionText] = useState("");
  const captionClearRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const [manageOpen, setManageOpen] = useState(false);
  const [viewers, setViewers] = useState<LiveViewerRow[]>([]);
  const [busyViewerId, setBusyViewerId] = useState<string | null>(null);
  const [talkBackActive, setTalkBackActive] = useState(false);
  const [talkBackMutedByHost, setTalkBackMutedByHost] = useState(false);
  const [billingEnabled, setBillingEnabled] = useState(false);
  const [isSubscriberViewer, setIsSubscriberViewer] = useState(false);
  const [sessionSeconds, setSessionSeconds] = useState(0);
  const [sessionCoins, setSessionCoins] = useState(0);
  const [billingToast, setBillingToast] = useState("");

  const sessionSecondsRef = useRef(0);
  const sessionCoinsRef = useRef(0);
  const initialBalanceRef = useRef(0);
  const billingEnabledRef = useRef(false);
  const talkBackActiveRef = useRef(false);
  const endingForBalanceRef = useRef(false);
  const talkBackIdsRef = useRef<Set<string>>(new Set());
  const mutedTalkBackIdsRef = useRef<Set<string>>(new Set());

  const mergeViewerFlags = useCallback((rows: LiveViewerRow[]) => {
    return rows.map((row) => ({
      ...row,
      talkBack: row.talkBack === true || talkBackIdsRef.current.has(row.id),
      muted:
        row.muted === true ||
        (talkBackIdsRef.current.has(row.id) && mutedTalkBackIdsRef.current.has(row.id)),
    }));
  }, []);

  const syncTalkBackSetsFromRows = useCallback((rows: LiveViewerRow[]) => {
    for (const row of rows) {
      if (row.talkBack) talkBackIdsRef.current.add(row.id);
      if (row.muted && (row.talkBack || talkBackIdsRef.current.has(row.id))) {
        mutedTalkBackIdsRef.current.add(row.id);
      }
    }
  }, []);

  const showCaption = useCallback((text: string) => {
    if (!text || !captionsOn) return;
    setCaptionText(text);
    if (captionClearRef.current) clearTimeout(captionClearRef.current);
    captionClearRef.current = setTimeout(() => {
      setCaptionText("");
      captionClearRef.current = null;
    }, 20000);
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
  const isPaidStream = Boolean(stream?.isPaid && (stream?.pricePerMinute ?? 0) > 0);
  const pricePerMinute = stream?.pricePerMinute ?? 0;
  const agoraRole: "host" | "audience" = isBroadcaster ? "host" : "audience";
  const showGift = Boolean(user && !isHost && giftCatalog.length);

  const pumpTranslateQueue = useCallback(async () => {
    if (translatePumpRef.current) return;
    translatePumpRef.current = true;
    try {
      while (translateQueueRef.current.length) {
        const job = translateQueueRef.current.shift();
        if (!job) break;
        const text = job.text.trim();
        if (text.length < LIVE_SEGMENT_MIN) continue;
        const translated = await translateLiveText({
          text,
          source: null,
          target: targetLangRef.current,
        });
        if (!translated.translated) continue;
        const line = translated.text.trim();
        if (!line) continue;
        lastGoodCaptionRef.current = line;
        showCaption(line);
        if (job.speak && hearTranslateRef.current) {
          const spokenKey = line
            .toLowerCase()
            .replace(/[.!?。！？,"'”“’‘]+/g, "")
            .replace(/\s+/g, " ")
            .trim();
          if (lastSpokenSegmentRef.current === spokenKey) continue;
          lastSpokenSegmentRef.current = spokenKey;
          void speakLiveTranslation(line, targetLangRef.current);
        }
      }
    } finally {
      translatePumpRef.current = false;
      if (translateQueueRef.current.length) void pumpTranslateQueue();
    }
  }, [showCaption]);

  const enqueueViewerTranslate = useCallback(
    (text: string, speak: boolean) => {
      const cleaned = text.replace(/\s+/g, " ").trim();
      if (cleaned.length < LIVE_SEGMENT_MIN) return;
      if (speak) {
        translateQueueRef.current.push({ text: cleaned, speak: true });
      } else {
        const last = translateQueueRef.current[translateQueueRef.current.length - 1];
        if (last && !last.speak) {
          last.text = cleaned;
        } else {
          translateQueueRef.current.push({ text: cleaned, speak: false });
        }
      }
      void pumpTranslateQueue();
    },
    [pumpTranslateQueue]
  );

  const handleViewerTranscript = useCallback(
    (chunk: CaptionChunk) => {
      const shown = captionTextForRole(chunk, isHost);
      if (!shown) return;

      if (isHost) {
        showCaption(shown);
        return;
      }

      targetLangRef.current = normalizeLiveLang(user?.language) || "en";
      const isFinal = chunk.isFinal !== false;
      const segment = shown.replace(/\s+/g, " ").trim();

      if (!isFinal) {
        interimTextRef.current = segment;
        if (interimTimerRef.current) clearTimeout(interimTimerRef.current);
        interimTimerRef.current = setTimeout(() => {
          interimTimerRef.current = null;
          enqueueViewerTranslate(interimTextRef.current, false);
        }, 400);
        return;
      }

      if (interimTimerRef.current) {
        clearTimeout(interimTimerRef.current);
        interimTimerRef.current = null;
      }
      enqueueViewerTranslate(segment, true);
    },
    [enqueueViewerTranslate, isHost, showCaption, user?.language]
  );

  useEffect(() => {
    talkBackActiveRef.current = talkBackActive;
  }, [talkBackActive]);

  useEffect(() => {
    billingEnabledRef.current = billingEnabled;
  }, [billingEnabled]);

  const translatorLive = Boolean(stream?.captionsEnabled || stream?.saveEnabled);

  useEffect(() => {
    translatorLiveRef.current = translatorLive;
    if (!translatorLive) stopLiveSpeech();
  }, [translatorLive]);

  useEffect(() => {
    hearTranslateRef.current = hearTranslate;
    if (!hearTranslate) stopLiveSpeech();
    if (!isHost) {
      setRemoteAudioDucked(remoteUsersRef.current, translatorLive && hearTranslate);
    }
  }, [hearTranslate, isHost, translatorLive]);

  useEffect(() => {
    if (isHost || !translatorLive || !hearTranslate) return;
    const onPointer = () => unlockLiveSpeech();
    window.addEventListener("pointerdown", onPointer, { once: true });
    return () => window.removeEventListener("pointerdown", onPointer);
  }, [isHost, translatorLive, hearTranslate]);

  useEffect(() => {
    remoteUsersRef.current = remoteUsers;
    if (!isHost) {
      setRemoteAudioDucked(remoteUsers, translatorLiveRef.current && hearTranslateRef.current);
    }
  }, [remoteUsers, isHost]);

  useEffect(() => {
    return () => stopLiveSpeech();
  }, []);

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
    if (!stream?.id) return;
    let isCleanedUp = false;
    setJoinError("");
    setJoined(false);
    setTalkBackActive(false);
    setTalkBackMutedByHost(false);
    setBillingEnabled(false);
    setIsSubscriberViewer(false);
    setSessionSeconds(0);
    setSessionCoins(0);
    setViewers([]);
    sessionSecondsRef.current = 0;
    sessionCoinsRef.current = 0;
    initialBalanceRef.current = 0;
    billingEnabledRef.current = false;
    endingForBalanceRef.current = false;
    talkBackIdsRef.current.clear();
    mutedTalkBackIdsRef.current.clear();

    async function initAgora() {
      let joinedSocketRoom = false;
      try {
        let billThisViewer = false;
        let knownSubscriber = false;
        let subsLookupOk = false;

        if (isPaidStream && !isBroadcaster) {
          const [wallet, subsLookup] = await Promise.all([
            getWallet().catch(() => null),
            lookupMySubscriptions(),
          ]);
          if (isCleanedUp) return;

          subsLookupOk = subsLookup.ok;
          knownSubscriber = Boolean(
            subsLookup.ok && streamHostId && subsLookup.creatorIds.includes(streamHostId)
          );
          if (knownSubscriber) {
            setIsSubscriberViewer(true);
          } else if (subsLookup.ok) {
            const balance = wallet?.balance ?? 0;
            initialBalanceRef.current = balance;
            if (balance <= 0) {
              setJoinError("Not enough coins to join this private stream.");
              return;
            }
          }
        }

        const joinAck = await emitSocketAck<Record<string, unknown>>("join_stream", {
          streamId,
        }).catch(() => null);
        if (isCleanedUp) return;

        if (!joinAck || joinAck.ok !== true) {
          const msg = String(
            (joinAck && (joinAck.error || joinAck.message)) ||
              "Unable to join stream. Please retry."
          );
          const lower = msg.toLowerCase();
          setJoinError(
            lower.includes("balance") || lower.includes("insufficient")
              ? "Not enough coins to join this private stream."
              : msg
          );
          return;
        }
        joinedSocketRoom = true;

        const joinedCount = parseViewerCount(joinAck);
        if (joinedCount != null) setViewerCount((c) => Math.max(c, joinedCount));

        if (isPaidStream && !isBroadcaster) {
          if (joinAckSkipsBilling(joinAck)) {
            knownSubscriber = true;
            setIsSubscriberViewer(true);
          }
          billThisViewer = !knownSubscriber && subsLookupOk;
        }

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
            if (!isHost && translatorLiveRef.current && hearTranslateRef.current) {
              try {
                remoteUser.audioTrack?.setVolume?.(12);
              } catch {
              }
            }
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
          setJoinError("");
          setViewerCount((n) => Math.max(n, agoraRole === "audience" ? 1 : n));
          if (billThisViewer) {
            setBillingEnabled(true);
            billingEnabledRef.current = true;
          }
          if (isHost) {
            void requestStreamViewers(streamId);
          }
        }
      } catch (err) {
        console.error("Agora live join failed", err);
        if (joinedSocketRoom) {
          emitSocketAck("leave_stream", { streamId }).catch(() => {});
          joinedSocketRoom = false;
        }
        if (!isCleanedUp) {
          const msg = (err as Error)?.message || "Could not connect to the live stream.";
          const lower = msg.toLowerCase();
          setJoinError(
            lower.includes("balance") || lower.includes("insufficient")
              ? "Not enough coins to join this private stream."
              : msg
          );
        }
      }
    }

    initAgora();

    void listStreamChat(streamId, 1, 50)
      .then((rows) => {
        if (isCleanedUp || !Array.isArray(rows) || rows.length === 0) return;
        const history: LiveChatMessage[] = [];
        for (const row of rows) {
          const parsed = parseChatMessage(row, streamId);
          if (parsed) history.push(parsed);
        }
        if (!history.length) return;
        setMessages((prev) => mergeChatHistory(history, prev));
      })
      .catch(() => {});

    const applyViewers = (d: unknown) => {
      const n = parseViewerCount(d);
      if (n != null) setViewerCount(n);
    };

    let lastGiftKey = "";
    let lastGiftAt = 0;
    const pushGiftToast = (raw: unknown) => {
      void (async () => {
        const gift = await resolveGiftSocketEvent(raw);
        if (gift.streamId && gift.streamId !== streamId) return;
        if (isCleanedUp) return;
        const key = `${gift.senderName}|${gift.giftName}|${gift.quantity}`;
        const now = Date.now();
        if (key === lastGiftKey && now - lastGiftAt < 1500) return;
        lastGiftKey = key;
        lastGiftAt = now;
        giftToastSeqRef.current += 1;
        const id = `gift_${giftToastSeqRef.current}`;
        const text = isHost
          ? `${gift.senderName} sent ${gift.giftName} to you`
          : `${gift.senderName} sent ${gift.giftName}`;
        setGiftToasts((prev) => [...prev.slice(-4), { id, text }]);
        window.setTimeout(() => {
          setGiftToasts((prev) => prev.filter((t) => t.id !== id));
        }, 4200);
      })();
    };

    const offs = [
      onSocketEvent(socketEvents.viewerCount, applyViewers),
      onSocketEvent("viewer_count", applyViewers),
      onSocketEvent("stream_viewer_count", applyViewers),
      onSocketEvent(socketEvents.streamViewers, applyViewers),
      onSocketEvent<unknown>(socketEvents.streamChat, (d) => {
        const parsed = parseChatMessage(d, streamId);
        if (parsed) setMessages((m) => appendChatUnique(m, parsed));
      }),
      onSocketEvent(socketEvents.streamEnded, () => {
        router.push(`/live/${streamId}/summary`);
      }),
      onSocketEvent<unknown>(socketEvents.transcript, (raw) => {
        const chunk = normalizeCaptionPayload(raw);
        if (!chunk) return;
        if (chunk.streamId && chunk.streamId !== streamId) return;
        void handleViewerTranscript(chunk);
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
        void handleViewerTranscript(chunk);
      }),
      onSocketEvent<unknown>(socketEvents.giftSent, pushGiftToast),
      onSocketEvent<unknown>(socketEvents.streamGift, pushGiftToast),
      onSocketEvent<unknown>("gift_received", pushGiftToast),
    ];

    return () => {
      isCleanedUp = true;
      offs.forEach((o) => o());
      const leavePayload: Record<string, unknown> = { streamId };
      if (billingEnabledRef.current) {
        leavePayload.durationSeconds = sessionSecondsRef.current;
        leavePayload.chargedCoins = Math.ceil(sessionCoinsRef.current);
      }
      emitSocketAck("leave_stream", leavePayload).catch(() => {});

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
  }, [
    stream?.id,
    streamId,
    agoraRole,
    isBroadcaster,
    isHost,
    isPaidStream,
    streamHostId,
    router,
    showCaption,
    handleViewerTranscript,
    joinAttempt,
  ]);

  useEffect(() => {
    return () => {
      if (captionClearRef.current) clearTimeout(captionClearRef.current);
      if (interimTimerRef.current) clearTimeout(interimTimerRef.current);
    };
  }, []);

  useEffect(() => {
    if (!joined || !isHost) return;
    if (!stream?.captionsEnabled && !stream?.saveEnabled) return;
    if (isMuted) {
      setCaptionText("");
      stopLiveSpeech();
      return;
    }
    const stop = startHostSpeechCaptions({
      lang: user?.language,
      onChunk: (chunk) => {
        const shown = captionTextForRole(chunk, true);
        if (shown) showCaption(shown);
        emitTranscriptChunk(streamId, chunk);
      },
    });
    return stop;
  }, [joined, isHost, isMuted, stream?.captionsEnabled, stream?.saveEnabled, streamId, user?.language, showCaption]);

  useEffect(() => {
    if (!joined || !billingEnabled || isBroadcaster || pricePerMinute <= 0) return;
    const rate = pricePerMinute / 60;
    const timer = window.setInterval(() => {
      if (endingForBalanceRef.current) return;
      sessionSecondsRef.current += 1;
      sessionCoinsRef.current = sessionSecondsRef.current * rate;
      setSessionSeconds(sessionSecondsRef.current);
      setSessionCoins(sessionCoinsRef.current);
      const remaining = initialBalanceRef.current - sessionCoinsRef.current;
      if (remaining <= 0) {
        endingForBalanceRef.current = true;
        window.clearInterval(timer);
        setBillingToast("Private stream ended — your balance ran out.");
        router.push("/live");
      }
    }, 1000);
    return () => window.clearInterval(timer);
  }, [joined, billingEnabled, isBroadcaster, pricePerMinute, router]);

  const enableTalkBackMic = useCallback(async () => {
    const client = clientRef.current;
    if (!client || isBroadcaster) return;
    try {
      await client.setClientRole("host");
      if (!localAudioTrackRef.current) {
        const AgoraRTC = (await import("agora-rtc-sdk-ng")).default;
        const mic = await AgoraRTC.createMicrophoneAudioTrack();
        localAudioTrackRef.current = mic;
        await client.publish([mic]);
      } else {
        await localAudioTrackRef.current.setEnabled(true);
      }
      setTalkBackActive(true);
      setTalkBackMutedByHost(false);
      setIsMuted(false);
    } catch (err) {
      console.error("Talk-back enable failed", err);
    }
  }, [isBroadcaster]);

  const disableTalkBackMic = useCallback(async () => {
    const client = clientRef.current;
    const mic = localAudioTrackRef.current;
    if (mic) {
      try {
        await client?.unpublish(mic);
      } catch {}
      mic.stop();
      mic.close();
      localAudioTrackRef.current = null;
    }
    try {
      await client?.setClientRole("audience");
    } catch {}
    setTalkBackActive(false);
    setTalkBackMutedByHost(false);
    setIsMuted(false);
  }, []);

  const setTalkBackMicEnabled = useCallback(async (enabled: boolean) => {
    if (!localAudioTrackRef.current || !talkBackActiveRef.current) return;
    await localAudioTrackRef.current.setEnabled(enabled);
    setTalkBackMutedByHost(!enabled);
    setIsMuted(!enabled);
  }, []);

  useEffect(() => {
    if (!joined || !streamId) return;
    const me = user?.id ?? "";

    const applyViewersList = (d: unknown) => {
      if (eventStreamId(d) && eventStreamId(d) !== streamId) return;
      const rows = parseViewerRows(d);
      if (rows.length || Array.isArray((d as Record<string, unknown>)?.viewers)) {
        syncTalkBackSetsFromRows(rows);
        setViewers(mergeViewerFlags(rows));
      }
      const n = parseViewerCount(d);
      if (n != null) setViewerCount(n);
    };

    const offs = [
      onSocketEvent(socketEvents.streamViewers, applyViewersList),
      onSocketEvent("stream_viewers", applyViewersList),
      onSocketEvent<unknown>(socketEvents.billingTick, (d) => {
        if (!isPrivateStream) return;
        if (eventStreamId(d) && eventStreamId(d) !== streamId) return;
        const o = (d && typeof d === "object" ? d : {}) as Record<string, unknown>;
        const amount = o.charged ?? o.amount ?? o.coins;
        const ppm = o.pricePerMinute;
        if (amount != null) {
          const n = typeof amount === "number" ? amount : Number(amount);
          if (Number.isFinite(n) && n > 0 && billingEnabledRef.current) {
            sessionCoinsRef.current = Math.max(sessionCoinsRef.current, n);
            setSessionCoins(sessionCoinsRef.current);
          }
          const suffix = ppm != null ? ` (${ppm} coins/min)` : "";
          setBillingToast(`Billed: ${amount} coins${suffix}`);
          window.setTimeout(() => setBillingToast(""), 3200);
          void getWallet().catch(() => null);
        }
      }),
      onSocketEvent<unknown>(socketEvents.viewerRemoved, (d) => {
        if (eventStreamId(d) && eventStreamId(d) !== streamId) return;
        const removedId = eventUserId(d);
        if (!removedId || !me || removedId !== me) return;
        const reason = String((d as Record<string, unknown>)?.reason ?? "");
        setBillingToast(
          reason === "billing_failed"
            ? "Removed from stream — insufficient wallet balance"
            : isCohost
              ? "You were removed as co-host"
              : "You were removed from the stream"
        );
        router.push("/live");
      }),
      onSocketEvent<unknown>(socketEvents.viewerMuted, (d) => {
        if (!isPrivateStream) return;
        if (eventStreamId(d) && eventStreamId(d) !== streamId) return;
        const mutedId = eventUserId(d);
        if (mutedId) mutedTalkBackIdsRef.current.add(mutedId);
        if (mutedId && me && mutedId === me && talkBackActiveRef.current) {
          void setTalkBackMicEnabled(false);
          setBillingToast("Host muted your mic");
          window.setTimeout(() => setBillingToast(""), 2800);
        }
        setViewers((prev) =>
          mergeViewerFlags(prev.map((v) => (v.id === mutedId ? { ...v, muted: true } : v)))
        );
      }),
      onSocketEvent<unknown>(socketEvents.viewerUnmuted, (d) => {
        if (!isPrivateStream) return;
        if (eventStreamId(d) && eventStreamId(d) !== streamId) return;
        const unmutedId = eventUserId(d);
        if (unmutedId) mutedTalkBackIdsRef.current.delete(unmutedId);
        if (unmutedId && me && unmutedId === me && talkBackActiveRef.current) {
          void setTalkBackMicEnabled(true);
          setBillingToast("You can speak again");
          window.setTimeout(() => setBillingToast(""), 2800);
        }
        setViewers((prev) =>
          mergeViewerFlags(prev.map((v) => (v.id === unmutedId ? { ...v, muted: false } : v)))
        );
      }),
      onSocketEvent<unknown>(socketEvents.talkBackGranted, (d) => {
        if (!isPrivateStream) return;
        if (eventStreamId(d) && eventStreamId(d) !== streamId) return;
        const uid = eventUserId(d);
        if (uid) {
          talkBackIdsRef.current.add(uid);
          mutedTalkBackIdsRef.current.delete(uid);
        }
        if (uid && me && uid === me) {
          void enableTalkBackMic();
          setBillingToast("Talk-back enabled");
          window.setTimeout(() => setBillingToast(""), 2800);
        }
        setViewers((prev) => {
          const exists = prev.some((v) => v.id === uid);
          const next = exists
            ? prev.map((v) => (v.id === uid ? { ...v, talkBack: true, muted: false } : v))
            : uid
              ? [...prev, { id: uid, name: "Viewer", talkBack: true, muted: false }]
              : prev;
          return mergeViewerFlags(next);
        });
      }),
      onSocketEvent<unknown>(socketEvents.talkBackRevoked, (d) => {
        if (!isPrivateStream) return;
        if (eventStreamId(d) && eventStreamId(d) !== streamId) return;
        const uid = eventUserId(d);
        if (uid) {
          talkBackIdsRef.current.delete(uid);
          mutedTalkBackIdsRef.current.delete(uid);
        }
        if (uid && me && uid === me) {
          void disableTalkBackMic();
          setBillingToast("Talk-back ended");
          window.setTimeout(() => setBillingToast(""), 2800);
        }
        setViewers((prev) =>
          mergeViewerFlags(
            prev.map((v) => (v.id === uid ? { ...v, talkBack: false, muted: false } : v))
          )
        );
      }),
    ];

    return () => offs.forEach((o) => o());
  }, [
    joined,
    streamId,
    user?.id,
    isPrivateStream,
    isCohost,
    router,
    enableTalkBackMic,
    disableTalkBackMic,
    setTalkBackMicEnabled,
    mergeViewerFlags,
    syncTalkBackSetsFromRows,
  ]);

  async function toggleMute() {
    if (!localAudioTrackRef.current) return;
    if (talkBackActive && talkBackMutedByHost) return;
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

  async function onToggleViewerMute(viewer: LiveViewerRow) {
    const hasTalkBack = viewer.talkBack || talkBackIdsRef.current.has(viewer.id);
    if (!hasTalkBack) return;
    const isMutedNow = viewer.muted || mutedTalkBackIdsRef.current.has(viewer.id);
    setBusyViewerId(viewer.id);
    try {
      const ok = isMutedNow
        ? await unmuteStreamViewer(streamId, viewer.id)
        : await muteStreamViewer(streamId, viewer.id);
      if (ok) {
        if (isMutedNow) mutedTalkBackIdsRef.current.delete(viewer.id);
        else mutedTalkBackIdsRef.current.add(viewer.id);
        setViewers((prev) =>
          mergeViewerFlags(
            prev.map((v) => (v.id === viewer.id ? { ...v, muted: !isMutedNow, talkBack: true } : v))
          )
        );
      }
    } finally {
      setBusyViewerId(null);
    }
  }

  async function onToggleViewerTalkBack(viewer: LiveViewerRow) {
    const granted = viewer.talkBack || talkBackIdsRef.current.has(viewer.id);
    setBusyViewerId(viewer.id);
    try {
      const ok = granted
        ? await revokeTalkBack(streamId, viewer.id)
        : await grantTalkBack(streamId, viewer.id);
      if (ok) {
        if (granted) {
          talkBackIdsRef.current.delete(viewer.id);
          mutedTalkBackIdsRef.current.delete(viewer.id);
        } else {
          talkBackIdsRef.current.add(viewer.id);
        }
        setViewers((prev) =>
          mergeViewerFlags(
            prev.map((v) =>
              v.id === viewer.id
                ? { ...v, talkBack: !granted, muted: granted ? false : v.muted }
                : v
            )
          )
        );
      }
    } finally {
      setBusyViewerId(null);
    }
  }

  async function onRemoveViewer(viewerId: string) {
    setBusyViewerId(viewerId);
    try {
      const ok = await removeStreamViewer(streamId, viewerId);
      if (ok) {
        talkBackIdsRef.current.delete(viewerId);
        mutedTalkBackIdsRef.current.delete(viewerId);
        setViewers((prev) => prev.filter((v) => v.id !== viewerId));
      }
    } finally {
      setBusyViewerId(null);
    }
  }

  function sendChat() {
    if (!chatInput.trim()) return;
    const content = chatInput.trim();
    emitSocket("stream_chat_message", { streamId, content });
    setMessages((m) =>
      appendChatUnique(m, {
        content,
        userId: user?.id,
        userName: user?.username ? `@${user.username}` : "@you",
      })
    );
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
      setMessages((m) =>
        appendChatUnique(m, {
          content,
          userId: user?.id,
          userName: user?.username ? `@${user.username}` : "@you",
          mediaUrl: uploaded.mediaUrl || undefined,
          mediaType: uploaded.mediaType,
          fileName: uploaded.fileName,
        })
      );
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
      {isHost ? (
        <LiveManageViewersSheet
          open={manageOpen}
          onClose={() => setManageOpen(false)}
          viewers={viewers}
          talkBackControls={isPrivateStream}
          busyId={busyViewerId}
          onToggleMute={(v) => void onToggleViewerMute(v)}
          onToggleTalkBack={(v) => void onToggleViewerTalkBack(v)}
          onRemove={(id) => void onRemoveViewer(id)}
        />
      ) : null}

      <div className="relative min-h-0 flex-1 p-2 md:p-3">
        {!joined ? (
          <div className="absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 bg-neutral-950 px-6 text-center">
            {stream?.thumbnailUrl || stream?.host?.avatarUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={cloudinaryUrl(stream.thumbnailUrl || stream.host?.avatarUrl || "")}
                alt=""
                className="absolute inset-0 h-full w-full object-cover opacity-30 blur-2xl"
              />
            ) : null}
            <div className="relative z-10 flex max-w-sm flex-col items-center gap-3">
              {joinError ? (
                <>
                  <p className="font-sans text-sm font-semibold text-white">{joinError}</p>
                  <div className="flex flex-wrap items-center justify-center gap-2">
                    <button
                      type="button"
                      onClick={() => setJoinAttempt((n) => n + 1)}
                      className="rounded-xl brand-gradient px-4 py-2 text-xs font-bold text-white"
                    >
                      Retry
                    </button>
                    {joinError.toLowerCase().includes("coins") || joinError.toLowerCase().includes("balance") ? (
                      <button
                        type="button"
                        onClick={() => router.push("/wallet")}
                        className="rounded-xl border border-white/15 bg-white/10 px-4 py-2 text-xs font-bold text-white"
                      >
                        Top up wallet
                      </button>
                    ) : null}
                  </div>
                </>
              ) : (
                <>
                  <div className="h-10 w-10 animate-pulse rounded-full brand-gradient" />
                  <p className="font-sans text-xs text-white/70">Connecting to live stream…</p>
                </>
              )}
            </div>
          </div>
        ) : null}

        <div className="absolute inset-x-0 top-0 z-30 flex items-center justify-between p-4 bg-gradient-to-b from-black/80 via-black/40 to-transparent">
          <div className="flex items-center gap-2">
            <span className="flex items-center gap-1.5 rounded-full bg-red-600 px-3 py-1 font-sans text-xs font-bold text-white shadow-lg shadow-red-600/30">
              <Radio className="h-3 w-3 animate-pulse" /> LIVE
            </span>
            {isPrivateStream ? (
              <span className="rounded-full border border-amber-400/40 bg-amber-500/20 px-2.5 py-1 font-sans text-[11px] font-bold text-amber-200">
                Private
              </span>
            ) : null}
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
            {isSubscriberViewer ? (
              <span className="rounded-full border border-brand-purple/40 bg-brand-purple/25 px-2.5 py-1 font-sans text-[11px] font-bold text-brand-purple">
                Subscriber
              </span>
            ) : null}
            {talkBackActive ? (
              <span className="flex items-center gap-1 rounded-full border border-emerald-400/40 bg-emerald-500/20 px-2.5 py-1 font-sans text-[11px] font-bold text-emerald-200">
                <AudioLines className="h-3 w-3" />
                Talk-back
              </span>
            ) : null}
            {stream?.title ? (
              <span className="hidden max-w-[40vw] truncate rounded-full bg-black/50 px-3 py-1 font-sans text-xs font-semibold text-white/90 sm:inline">
                {stream.title}
              </span>
            ) : null}
          </div>

          <div className="flex items-center gap-2">
            {(stream?.captionsEnabled || stream?.saveEnabled) ? (
              <>
                <button
                  type="button"
                  onClick={() => setCaptionsOn((v) => !v)}
                  className={cn(
                    "flex h-9 w-9 items-center justify-center rounded-full backdrop-blur-md transition active:scale-95",
                    captionsOn ? "bg-brand-purple/30 text-white" : "bg-black/60 text-white/70 hover:bg-black/80"
                  )}
                  title={captionsOn ? "Hide captions" : "Show captions"}
                  aria-label="Live captions"
                >
                  <Languages className="h-4 w-4" />
                </button>
                {!isHost ? (
                  <button
                    type="button"
                    onClick={() => {
                      setHearTranslate((v) => {
                        const next = !v;
                        if (next) unlockLiveSpeech();
                        return next;
                      });
                    }}
                    className={cn(
                      "flex h-9 w-9 items-center justify-center rounded-full backdrop-blur-md transition active:scale-95",
                      hearTranslate ? "bg-emerald-500/30 text-white" : "bg-black/60 text-white/70 hover:bg-black/80"
                    )}
                    title={hearTranslate ? "Hearing translation" : "Hear original only"}
                    aria-label="Hear translation"
                  >
                    <Headphones className="h-4 w-4" />
                  </button>
                ) : null}
              </>
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

        {billingEnabled && pricePerMinute > 0 ? (
          <div className="absolute inset-x-0 top-16 z-30 flex justify-center px-4">
            <div className="rounded-2xl border border-amber-400/30 bg-black/70 px-3.5 py-2 text-center backdrop-blur-md">
              <p className="font-sans text-[11px] font-semibold tabular-nums text-amber-100">
                {formatElapsed(sessionSeconds)} · {sessionCoins.toFixed(1)} coins spent ({pricePerMinute}/min)
              </p>
            </div>
          </div>
        ) : null}

        {billingToast ? (
          <div className="absolute inset-x-0 top-28 z-40 flex justify-center px-4">
            <p className="rounded-2xl border border-white/10 bg-black/80 px-3.5 py-2 text-center font-sans text-xs font-semibold text-white shadow-lg backdrop-blur-md">
              {billingToast}
            </p>
          </div>
        ) : null}

        {giftToasts.length ? (
          <div className="pointer-events-none absolute inset-x-0 top-1/3 z-40 flex flex-col items-center gap-2 px-4">
            {giftToasts.map((toast) => (
              <div
                key={toast.id}
                className="flex max-w-[min(92%,420px)] items-center gap-2 rounded-2xl border border-amber-300/30 bg-gradient-to-r from-[#8A2DDC]/95 to-[#E8487E]/95 px-4 py-3 shadow-xl shadow-brand-purple/30 backdrop-blur-md"
              >
                <Gift className="h-5 w-5 shrink-0 text-white" />
                <p className="font-sans text-sm font-bold leading-snug text-white">{toast.text}</p>
              </div>
            ))}
          </div>
        ) : null}

        <div className="absolute bottom-[88px] right-4 z-30 flex flex-col items-end gap-2 md:bottom-6">
          {chatMode === "closed" ? <LiveChatOpenButton onClick={() => setChatMode("open")} /> : null}
        </div>

        {talkBackActive && !isBroadcaster ? (
          <div className="absolute bottom-[88px] left-1/2 z-30 flex -translate-x-1/2 items-center gap-2 rounded-2xl border border-white/10 bg-black/75 px-3 py-2 backdrop-blur-xl md:bottom-6">
            <button
              type="button"
              onClick={() => void toggleMute()}
              disabled={talkBackMutedByHost}
              className={cn(
                "flex h-11 w-11 items-center justify-center rounded-xl border transition active:scale-95",
                isMuted || talkBackMutedByHost
                  ? "border-red-500/40 bg-red-500/20 text-red-400"
                  : "border-white/10 bg-white/10 text-white hover:bg-white/20",
                talkBackMutedByHost && "opacity-60"
              )}
              aria-label={isMuted ? "Unmute" : "Mute"}
              title={talkBackMutedByHost ? "Muted by host" : isMuted ? "Unmute" : "Mute"}
            >
              {isMuted || talkBackMutedByHost ? <MicOff className="h-5 w-5" /> : <Mic className="h-5 w-5" />}
            </button>
          </div>
        ) : null}

        {isBroadcaster && (
          <div className="absolute bottom-[88px] left-1/2 z-30 flex -translate-x-1/2 items-center gap-2 rounded-2xl border border-white/10 bg-black/75 px-3 py-2 backdrop-blur-xl md:bottom-6 md:gap-3 md:px-4">
            {isHost ? (
              <button
                type="button"
                onClick={() => {
                  setManageOpen(true);
                  void requestStreamViewers(streamId);
                }}
                className="flex h-11 w-11 items-center justify-center rounded-xl border border-white/10 bg-white/10 text-white transition hover:bg-white/20 active:scale-95"
                aria-label="Manage viewers"
                title="Manage viewers"
              >
                <Users className="h-5 w-5" />
              </button>
            ) : null}
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
