import { api, withQuery } from "./client";
import type { LiveStream, StreamInvite, XLiveUser } from "../types";

function hostFromRecord(raw: Record<string, unknown>): { hostId: string; host?: XLiveUser } {
  const hostRaw = (
    (raw.host && typeof raw.host === "object" ? raw.host : null) ||
    (raw.creator && typeof raw.creator === "object" ? raw.creator : null) ||
    (raw.user && typeof raw.user === "object" ? raw.user : null) ||
    (raw.owner && typeof raw.owner === "object" ? raw.owner : null) ||
    (raw.streamer && typeof raw.streamer === "object" ? raw.streamer : null)
  ) as Record<string, unknown> | null;
  const username = String(
    hostRaw?.username ?? hostRaw?.handle ?? raw.hostUsername ?? raw.hostHandle ?? raw.username ?? ""
  ).replace(/^@/, "");
  const hostId = String(raw.hostId ?? hostRaw?._id ?? hostRaw?.id ?? raw.userId ?? raw.creatorId ?? "");
  if (!hostId && !username) return { hostId: "" };
  return {
    hostId,
    host: {
      id: String(hostRaw?.id ?? hostRaw?._id ?? hostId),
      username,
      displayName: (hostRaw?.displayName ?? hostRaw?.name ?? raw.hostName) as string | undefined,
      avatarUrl: (hostRaw?.avatarUrl ?? hostRaw?.avatar ?? raw.hostAvatarUrl) as string | undefined,
    },
  };
}

function normalizeLiveRecord(raw: Record<string, unknown>): LiveStream {
  const nested =
    raw.stream && typeof raw.stream === "object" ? (raw.stream as Record<string, unknown>) : raw;
  const host = hostFromRecord({ ...nested, ...raw });
  const isPrivate =
    String(nested.visibility ?? raw.visibility ?? "").toLowerCase() === "private" ||
    Boolean(nested.isPrivate ?? raw.isPrivate);
  const rawPrice =
    nested.pricePerMinute ?? nested.privateStreamPricePerMinute ?? nested.coinsPerMinute ?? raw.pricePerMinute;
  const priceNum = typeof rawPrice === "number" ? rawPrice : Number(rawPrice ?? 0);
  const pricePerMinute = Number.isFinite(priceNum) && priceNum > 0 ? Math.floor(priceNum) : 0;
  return {
    id: String(nested._id ?? nested.id ?? raw._id ?? raw.id ?? ""),
    title: String(nested.title ?? raw.title ?? "Live stream"),
    caption: (nested.caption ?? raw.caption) ? String(nested.caption ?? raw.caption) : undefined,
    hostId: host.hostId,
    host: host.host,
    thumbnailUrl: (nested.thumbnailUrl ?? nested.previewUrl ?? nested.coverUrl ?? raw.thumbnailUrl) as
      | string
      | undefined,
    replayUrl: (nested.replayUrl ?? raw.replayUrl) ? String(nested.replayUrl ?? raw.replayUrl) : undefined,
    viewerCount:
      typeof nested.viewerCount === "number"
        ? nested.viewerCount
        : typeof raw.viewerCount === "number"
          ? raw.viewerCount
          : 0,
    isLive: nested.status === "live" || Boolean(nested.isLive ?? raw.isLive),
    startedAt: nested.startedAt ? String(nested.startedAt) : raw.startedAt ? String(raw.startedAt) : undefined,
    createdAt: nested.createdAt ? String(nested.createdAt) : raw.createdAt ? String(raw.createdAt) : undefined,
    hasReplay: Boolean(nested.replaySaved || nested.hasReplay || nested.replayUrl || raw.hasReplay || raw.replayUrl),
    captionsEnabled: nested.captionsEnabled === true || raw.captionsEnabled === true,
    captionsAvailable: nested.captionsAvailable === true || raw.captionsAvailable === true,
    saveEnabled: nested.saveEnabled === true || raw.saveEnabled === true,
    visibility: String(nested.visibility ?? raw.visibility ?? "public"),
    joinPolicy: nested.joinPolicy ? String(nested.joinPolicy) : undefined,
    chatPolicy: nested.chatPolicy ? String(nested.chatPolicy) : undefined,
    isPrivate,
    pricePerMinute,
    isPaid: isPrivate && pricePerMinute > 0,
  };
}

export async function getLiveStreams(): Promise<{ streams: LiveStream[] }> {
  const res = await api.get<Record<string, unknown>>("/api/x-live/streams/live", false);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? data.docs
    : Array.isArray(data?.streams)
    ? data.streams
    : Array.isArray(data)
    ? data
    : [];
  return {
    streams: (list as Record<string, unknown>[]).map(normalizeLiveRecord).filter((stream) => stream.id),
  };
}

export async function getStream(streamId: string): Promise<LiveStream> {
  const res = await api.get<Record<string, unknown>>(`/api/x-live/streams/${streamId}`, false);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? (res.data as Record<string, unknown>)
    : res) as Record<string, unknown>;
  return normalizeLiveRecord({ ...data, id: String(data._id ?? data.id ?? streamId) });
}

export async function createStream(payload: {
  title: string;
  caption?: string;
  visibility?: "public" | "private";
  isPrivate?: boolean;
  chatPolicy?: string;
  joinPolicy?: string;
  captionsEnabled?: boolean;
  saveEnabled?: boolean;
  durationMinutes?: number;
  inviteUserIds?: string[];
  pricePerMinute?: number;
}) {
  const isPriv = payload.visibility === "private" || Boolean(payload.isPrivate);
  const chatPolicy = payload.chatPolicy === "followers" ? "followers" : "everyone";
  const joinPolicy = isPriv
    ? "subscribers"
    : payload.joinPolicy === "followers" || payload.joinPolicy === "subscribers"
      ? payload.joinPolicy
      : "everyone";
  const body: Record<string, unknown> = {
    title: payload.title,
    caption: payload.caption ?? "",
    visibility: isPriv ? "private" : "public",
    joinPolicy,
    chatPolicy,
    durationMinutes: payload.durationMinutes && payload.durationMinutes > 0 ? payload.durationMinutes : 60,
    captionsEnabled: typeof payload.captionsEnabled === "boolean" ? payload.captionsEnabled : true,
    saveEnabled: typeof payload.saveEnabled === "boolean" ? payload.saveEnabled : true,
    inviteUserIds: Array.isArray(payload.inviteUserIds) ? payload.inviteUserIds : [],
  };
  if (isPriv && typeof payload.pricePerMinute === "number" && payload.pricePerMinute > 0) {
    body.pricePerMinute = payload.pricePerMinute;
  }
  const res = await api.post<Record<string, unknown>>("/api/x-live/streams", body);
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown>;
  return {
    id: String(data._id ?? data.id ?? ""),
    title: String(data.title ?? payload.title),
    hostId: String(data.hostId ?? ""),
    isLive: Boolean(data.isLive),
  } as LiveStream;
}

export async function startStream(streamId: string) {
  return api.post<LiveStream>(`/api/x-live/streams/${streamId}/start`);
}

export async function endStream(streamId: string) {
  return api.post(`/api/x-live/streams/${streamId}/end`);
}

export async function getStreamToken(streamId: string, role: "host" | "audience") {
  const res = await api.get<Record<string, unknown>>(
    withQuery(`/api/x-live/streams/${streamId}/token`, { role })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return {
    token: String(data.token ?? ""),
    channel: String(data.channel ?? data.channelName ?? ""),
    channelName: String(data.channelName ?? data.channel ?? ""),
    uid: (data.uid as string | number | undefined),
    appId: String(data.appId ?? ""),
  };
}

export async function sendStreamInvite(
  streamId: string,
  userId: string,
  opts?: { role?: string; earningsSplitPercent?: number }
) {
  const body: Record<string, unknown> = { userId };
  if (opts?.role) body.role = opts.role;
  if (typeof opts?.earningsSplitPercent === "number" && opts.earningsSplitPercent > 0) {
    body.earningsSplitPercent = opts.earningsSplitPercent;
  }
  return api.post(`/api/x-live/streams/${streamId}/invites`, body);
}

export async function getMyInvites(page = 1, limit = 20): Promise<{ invites: StreamInvite[] }> {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/streams/invites/mine", { page, limit })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? (data.docs as Record<string, unknown>[])
    : Array.isArray(data)
    ? (data as Record<string, unknown>[])
    : [];
  return {
    invites: list.map((doc) => {
      const streamDoc = (doc.stream && typeof doc.stream === "object" ? doc.stream : {}) as Record<string, unknown>;
      const hostDoc = (doc.host && typeof doc.host === "object" ? doc.host : {}) as Record<string, unknown>;
      return {
        id: String(doc._id ?? doc.id ?? ""),
        streamId: String(doc.streamId ?? streamDoc._id ?? streamDoc.id ?? ""),
        hostId: String(doc.hostId ?? hostDoc.id ?? hostDoc._id ?? ""),
        inviteeId: String(doc.inviteeId ?? ""),
        role: String(doc.role ?? "viewer"),
        earningsSplitPercent: typeof doc.earningsSplitPercent === "number" ? doc.earningsSplitPercent : undefined,
        status: String(doc.status ?? "pending"),
        streamTitle: String(streamDoc.title ?? "Live stream"),
        streamStatus: String(streamDoc.status ?? "live"),
        hostName: String(hostDoc.displayName ?? hostDoc.username ?? "A creator"),
        hostAvatarUrl: hostDoc.avatarUrl ? String(hostDoc.avatarUrl) : undefined,
      };
    }),
  };
}

export async function acceptStreamInvite(inviteId: string) {
  return api.post(`/api/x-live/streams/invites/${inviteId}/accept`);
}

export async function declineStreamInvite(inviteId: string) {
  return api.post(`/api/x-live/streams/invites/${inviteId}/decline`);
}

export async function getUserFollowers(userId: string, page = 1, limit = 40): Promise<{ users: XLiveUser[] }> {
  const res = await api.get<Record<string, unknown>>(
    withQuery(`/api/x-live/follow/${userId}/followers`, { page, limit }),
    false
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? (data.docs as XLiveUser[])
    : Array.isArray(data)
    ? (data as XLiveUser[])
    : [];
  return { users: list };
}

export async function getUserFollowing(userId: string, page = 1, limit = 40): Promise<{ users: XLiveUser[] }> {
  const res = await api.get<Record<string, unknown>>(
    withQuery(`/api/x-live/follow/${userId}/following`, { page, limit }),
    false
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? (data.docs as XLiveUser[])
    : Array.isArray(data)
    ? (data as XLiveUser[])
    : [];
  return { users: list };
}

export async function getReplays(page = 1, limit = 30): Promise<{ replays: LiveStream[] }> {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/streams/replays", { page, limit }),
    false
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? (data.docs as Record<string, unknown>[])
    : Array.isArray(data?.replays)
    ? (data.replays as Record<string, unknown>[])
    : Array.isArray(data)
    ? (data as Record<string, unknown>[])
    : [];
  return {
    replays: list.map(normalizeLiveRecord).filter((stream) => stream.id),
  };
}

export async function getReplay(streamId: string): Promise<{
  streamId: string;
  title: string;
  replayUrl?: string;
  thumbnailUrl?: string;
  recordingStatus?: string;
}> {
  const res = await api.get<Record<string, unknown>>(`/api/x-live/streams/${streamId}/replay`, false);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const rec = (data.recording && typeof data.recording === "object" ? data.recording : undefined) as Record<string, unknown> | undefined;
  return {
    streamId: String(data.streamId ?? streamId),
    title: typeof data.title === "string" ? data.title : "Live stream replay",
    replayUrl: (data.replayUrl ?? rec?.replayUrl) ? String(data.replayUrl ?? rec?.replayUrl) : undefined,
    thumbnailUrl: (data.thumbnailUrl ?? rec?.thumbnailUrl) ? String(data.thumbnailUrl ?? rec?.thumbnailUrl) : undefined,
    recordingStatus: String(data.recordingStatus ?? rec?.status ?? ""),
  };
}

export async function getStreamTranscript(streamId: string) {
  return api.get(`/api/x-live/streams/${streamId}/transcript`);
}

export async function uploadStreamChatFile(
  streamId: string,
  file: File,
  mediaType: "image" | "video" | "document",
  content?: string
) {
  const form = new FormData();
  form.append("file", file);
  form.append("filename", file.name);
  form.append("mediaType", mediaType);
  if (content?.trim()) form.append("content", content.trim());
  const res = await api.upload<Record<string, unknown>>(`/api/x-live/streams/${streamId}/chat/upload`, form);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const nested = (data.message && typeof data.message === "object" ? data.message : data) as Record<string, unknown>;
  return {
    content: String(nested.content ?? nested.text ?? content ?? file.name),
    mediaUrl: String(nested.mediaUrl ?? nested.url ?? nested.fileUrl ?? nested.attachmentUrl ?? ""),
    mediaType: String(nested.mediaType ?? mediaType),
    fileName: String(nested.fileName ?? nested.filename ?? file.name),
  };
}

export async function getStreamGifts(streamId: string) {
  return api.get(`/api/x-live/streams/${streamId}/gifts`);
}

export async function listStreamChat(streamId: string, page = 1, limit = 50): Promise<Record<string, unknown>[]> {
  const res = await api.get<Record<string, unknown>>(
    withQuery(`/api/x-live/streams/${streamId}/chat`, { page, limit })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? data.docs
    : Array.isArray(data?.messages)
    ? data.messages
    : Array.isArray(data?.items)
    ? data.items
    : Array.isArray(data?.chat)
    ? data.chat
    : Array.isArray(data)
    ? data
    : Array.isArray(res)
    ? res
    : [];
  return list as Record<string, unknown>[];
}

export async function uploadReplay(streamId: string, file: File) {
  const form = new FormData();
  form.append("replay", file);
  return api.upload(`/api/x-live/streams/${streamId}/replay`, form);
}
