import { api, withQuery } from "./client";
import type { ChatMessage, ChatThread, GroupSummary } from "../types";
import { publicHandle } from "../utils";
import { getUserProfile } from "./feed";
import {
  applyChatFileName,
  pickChatMediaTypeField,
  rememberChatUploadName,
  resolveChatMediaKind,
} from "../chat-media";
import { config } from "../config";
import { session } from "../session";

const senderHandleCache = new Map<string, string>();

function handleFromRecord(source?: Record<string, unknown> | null): string {
  if (!source) return "";
  return publicHandle({
    username: source.username as string | undefined,
    handle: source.handle as string | undefined,
    userName: source.userName as string | undefined,
    email: source.email as string | undefined,
  });
}

function pickMessageHandle(doc: Record<string, unknown>, raw: Record<string, unknown> | null): string {
  const sender =
    doc.sender && typeof doc.sender === "object" ? (doc.sender as Record<string, unknown>) : null;
  return (
    handleFromRecord(sender) ||
    publicHandle(doc.senderUsername as string) ||
    publicHandle(raw?.senderUsername as string) ||
    publicHandle(doc.username as string) ||
    publicHandle(doc.handle as string) ||
    publicHandle(doc.senderName as string) ||
    publicHandle(raw?.senderName as string)
  );
}

function parseGroupMembers(raw: unknown): NonNullable<GroupSummary["members"]> {
  if (!Array.isArray(raw)) return [];
  const members: NonNullable<GroupSummary["members"]> = [];
  for (const item of raw) {
    if (typeof item === "string") {
      members.push({ id: item });
      continue;
    }
    if (!item || typeof item !== "object") continue;
    const o = item as Record<string, unknown>;
    const nested =
      o.user && typeof o.user === "object"
        ? (o.user as Record<string, unknown>)
        : o.member && typeof o.member === "object"
        ? (o.member as Record<string, unknown>)
        : o.profile && typeof o.profile === "object"
        ? (o.profile as Record<string, unknown>)
        : o;
    const id = String(nested.id ?? nested._id ?? o.userId ?? o.memberId ?? o.id ?? o._id ?? "");
    if (!id) continue;
    members.push({
      id,
      username: handleFromRecord(nested) || handleFromRecord(o) || undefined,
      avatarUrl: (nested.avatarUrl ?? nested.avatar ?? o.avatarUrl) as string | undefined,
    });
  }
  return members;
}

export function seedSenderHandles(members?: GroupSummary["members"]) {
  for (const member of members || []) {
    const handle = publicHandle(member);
    if (member.id && handle) senderHandleCache.set(member.id, handle);
  }
}

export async function fillMessageHandles(messages: ChatMessage[]): Promise<ChatMessage[]> {
  const missing = Array.from(
    new Set(
      messages.flatMap((m) => {
        const ids: string[] = [];
        if (m.senderId && !publicHandle(m.senderName) && !senderHandleCache.has(m.senderId)) {
          ids.push(m.senderId);
        }
        if (
          m.replyTo?.senderId &&
          !publicHandle(m.replyTo.senderName) &&
          !senderHandleCache.has(m.replyTo.senderId)
        ) {
          ids.push(m.replyTo.senderId);
        }
        return ids;
      })
    )
  );

  await Promise.all(
    missing.map(async (id) => {
      try {
        const profile = await getUserProfile(id);
        senderHandleCache.set(id, publicHandle(profile) || "");
      } catch {
        senderHandleCache.set(id, "");
      }
    })
  );

  return messages.map((m) => ({
    ...m,
    senderName: publicHandle(m.senderName) || senderHandleCache.get(m.senderId) || undefined,
    replyTo: m.replyTo
      ? {
          ...m.replyTo,
          senderName:
            publicHandle(m.replyTo.senderName) ||
            (m.replyTo.senderId ? senderHandleCache.get(m.replyTo.senderId) : undefined) ||
            undefined,
        }
      : m.replyTo,
  }));
}

export function normalizeChatMessage(input: unknown): ChatMessage {
  const raw = (Array.isArray(input) ? input[0] : input) as Record<string, unknown> | null;
  const doc = (
    raw?.message && typeof raw.message === "object"
      ? raw.message
      : raw?.data && typeof raw.data === "object"
      ? raw.data
      : raw?.doc && typeof raw.doc === "object"
      ? raw.doc
      : raw
  ) as Record<string, unknown> || {};

  const id = String(doc._id ?? doc.id ?? doc.messageId ?? raw?._id ?? raw?.id ?? raw?.messageId ?? "");
  const chatId = String(
    doc.chatId ?? doc.dmChatId ?? doc.groupId ?? raw?.chatId ?? raw?.dmChatId ?? raw?.groupId ?? ""
  );

  let senderId = String(doc.senderId ?? raw?.senderId ?? "");
  if (!senderId && doc.sender) {
    if (typeof doc.sender === "string") {
      senderId = doc.sender;
    } else if (typeof doc.sender === "object") {
      const s = doc.sender as Record<string, unknown>;
      senderId = String(s.id ?? s._id ?? "");
    }
  }

  const senderName = pickMessageHandle(doc, raw);

  let senderAvatar = (doc.senderAvatar ?? raw?.senderAvatar) as string | undefined;
  if (!senderAvatar && doc.sender && typeof doc.sender === "object") {
    const s = doc.sender as Record<string, unknown>;
    senderAvatar = (s.avatarUrl ?? s.avatar) as string | undefined;
  }

  const content = String(doc.content ?? doc.text ?? doc.body ?? raw?.content ?? raw?.text ?? "");
  const attachment =
    (doc.attachment && typeof doc.attachment === "object" ? (doc.attachment as Record<string, unknown>) : null) ||
    (doc.file && typeof doc.file === "object" ? (doc.file as Record<string, unknown>) : null) ||
    (doc.media && typeof doc.media === "object" ? (doc.media as Record<string, unknown>) : null);
  const mediaUrl = (doc.mediaUrl ??
    doc.url ??
    doc.fileUrl ??
    doc.attachmentUrl ??
    doc.downloadUrl ??
    attachment?.url ??
    attachment?.fileUrl ??
    attachment?.mediaUrl ??
    attachment?.downloadUrl ??
    raw?.mediaUrl ??
    raw?.url ??
    raw?.fileUrl) as string | undefined;
  const mediaType = resolveChatMediaKind(pickChatMediaTypeField(doc, raw ?? undefined), mediaUrl);
  const createdAt = String(doc.createdAt ?? doc.timestamp ?? raw?.createdAt ?? new Date().toISOString());
  const editedAt = doc.editedAt ? String(doc.editedAt) : undefined;

  const replyDoc = (
    doc.replyTo && typeof doc.replyTo === "object"
      ? doc.replyTo
      : doc.replyToMessage && typeof doc.replyToMessage === "object"
      ? doc.replyToMessage
      : raw?.replyTo && typeof raw.replyTo === "object"
      ? raw.replyTo
      : null
  ) as Record<string, unknown> | null;

  const replyToMessageId = (
    doc.replyToMessageId ??
    doc.replyToId ??
    doc.parentMessageId ??
    raw?.replyToMessageId ??
    (replyDoc ? replyDoc._id ?? replyDoc.id : undefined)
  ) as string | undefined;

  let replyTo: ChatMessage["replyTo"] = undefined;
  if (replyDoc) {
    const rSender = (
      replyDoc.sender && typeof replyDoc.sender === "object" ? replyDoc.sender : null
    ) as Record<string, unknown> | null;
    replyTo = {
      id: String(replyDoc._id ?? replyDoc.id ?? replyToMessageId ?? ""),
      senderId: (replyDoc.senderId ?? (rSender ? rSender.id ?? rSender._id : undefined)) as string | undefined,
      senderName:
        handleFromRecord(rSender) ||
        publicHandle(replyDoc.senderName as string) ||
        publicHandle(replyDoc.senderUsername as string) ||
        undefined,
      content: (replyDoc.content ?? replyDoc.text ?? replyDoc.body) as string | undefined,
      mediaUrl: (replyDoc.mediaUrl ?? replyDoc.url) as string | undefined,
      mediaType: resolveChatMediaKind(
        pickChatMediaTypeField(replyDoc),
        (replyDoc.mediaUrl ?? replyDoc.url) as string | undefined
      ),
    };
  } else if (doc.replyToContent || doc.replyToSenderName) {
    replyTo = {
      id: String(replyToMessageId ?? ""),
      senderName: publicHandle(String(doc.replyToSenderName ?? "")) || undefined,
      content: doc.replyToContent ? String(doc.replyToContent) : undefined,
    };
  }

  let reactions: { emoji: string; userId?: string; count?: number; userIds?: string[] }[] = [];
  const rawReactions = doc.reactions ?? raw?.reactions;
  if (Array.isArray(rawReactions)) {
    reactions = (rawReactions as Record<string, unknown>[])
      .map((r) => ({
        emoji: String(r.emoji || r.reaction || ""),
        userId: r.userId ? String(r.userId) : undefined,
        count: typeof r.count === "number" ? r.count : 1,
        userIds: Array.isArray(r.userIds) ? (r.userIds as unknown[]).map(String) : (r.userId ? [String(r.userId)] : []),
      }))
      .filter((r) => Boolean(r.emoji));
  } else if (rawReactions && typeof rawReactions === "object") {
    const rawMap = rawReactions as Record<string, unknown>;
    for (const [emoji, val] of Object.entries(rawMap)) {
      if (Array.isArray(val)) {
        reactions.push({
          emoji,
          count: val.length,
          userIds: (val as unknown[]).map((item) => {
            if (item && typeof item === "object" && "userId" in (item as Record<string, unknown>)) {
              return String((item as Record<string, unknown>).userId);
            }
            return String(item);
          }),
        });
      } else if (typeof val === "number") {
        reactions.push({ emoji, count: val });
      }
    }
  }

  const message: ChatMessage = {
    id,
    chatId,
    senderId,
    senderName: senderName || undefined,
    senderAvatar,
    content,
    mediaUrl,
    mediaType,
    createdAt,
    editedAt,
    replyToMessageId,
    replyTo,
    reactions,
    fileName: (typeof doc.fileName === "string" && doc.fileName.trim()
      ? doc.fileName
      : typeof doc.originalName === "string" && doc.originalName.trim()
      ? doc.originalName
      : typeof doc.filename === "string" && doc.filename.trim()
      ? doc.filename
      : typeof doc.originalFilename === "string" && doc.originalFilename.trim()
      ? doc.originalFilename
      : undefined) as string | undefined,
  };
  return applyChatFileName(message);
}

function parseUploadBody(text: string) {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function uploadChatForm(
  path: string,
  form: FormData,
  onProgress?: (pct: number) => void
): Promise<Record<string, unknown>> {
  if (!onProgress) {
    return api.upload<Record<string, unknown>>(path, form);
  }
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("POST", `${config.apiBaseUrl}${path}`);
    const jwt = session.getJwt();
    if (jwt) xhr.setRequestHeader("Authorization", `Bearer ${jwt}`);
    xhr.upload.onprogress = (event) => {
      if (event.lengthComputable && event.total > 0) {
        onProgress(Math.min(99, Math.round((event.loaded / event.total) * 100)));
      }
    };
    xhr.onload = () => {
      const body = parseUploadBody(xhr.responseText);
      if (xhr.status >= 200 && xhr.status < 300) {
        onProgress(100);
        resolve((body && typeof body === "object" ? body : {}) as Record<string, unknown>);
        return;
      }
      const message =
        body && typeof body === "object" && typeof (body as Record<string, unknown>).message === "string"
          ? String((body as Record<string, unknown>).message)
          : "Upload failed";
      reject(new Error(message));
    };
    xhr.onerror = () => reject(new Error("Upload failed"));
    xhr.send(form);
  });
}

export function previewFromLastMessage(raw: unknown): string | undefined {
  if (typeof raw === "string" && raw.trim()) return raw.trim();
  if (raw && typeof raw === "object") {
    const o = raw as Record<string, unknown>;
    const nested = o.lastMessage && typeof o.lastMessage === "object" ? (o.lastMessage as Record<string, unknown>) : o;
    const text = nested.content ?? nested.text ?? nested.body ?? nested.preview ?? o.content ?? o.text;
    if (typeof text === "string" && text.trim()) return text.trim();
    if (nested.mediaUrl || nested.mediaType || o.mediaUrl || o.mediaType) return "Attachment";
  }
  return undefined;
}

export async function getChats(): Promise<{ chats: ChatThread[] }> {
  const res = await api.get<Record<string, unknown>>("/api/x-live/chats");
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? (data.docs as Record<string, unknown>[])
    : Array.isArray(data?.chats)
    ? (data.chats as Record<string, unknown>[])
    : Array.isArray(data)
    ? (data as Record<string, unknown>[])
    : [];
  return {
    chats: list.map((c) => {
      const peerRaw = (c.otherUser ?? c.peer ?? c.user) as Record<string, unknown> | undefined;
      const peer = peerRaw
        ? {
            id: String(peerRaw.id ?? peerRaw._id ?? ""),
            username: String(peerRaw.username ?? peerRaw.handle ?? "").replace(/^@/, "") || publicHandle(peerRaw.email as string),
            displayName: (peerRaw.displayName ?? peerRaw.name ?? peerRaw.username) as string | undefined,
            avatarUrl: (peerRaw.avatarUrl ?? peerRaw.avatar) as string | undefined,
          }
        : undefined;
      return {
        id: String(c._id ?? c.id ?? ""),
        peer,
        lastMessage: previewFromLastMessage(c.lastMessage) ?? previewFromLastMessage(c) ?? (c.lastMessageAt ? "Active conversation" : undefined),
        lastMessageAt: typeof c.lastMessageAt === "string" ? c.lastMessageAt : typeof c.updatedAt === "string" ? c.updatedAt : undefined,
        unreadCount: typeof c.unreadCount === "number" ? c.unreadCount : 0,
      };
    }),
  };
}

export async function getUnreadSummary(): Promise<{ total: number }> {
  const res = await api.get<Record<string, unknown>>("/api/x-live/chats/unread/summary");
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return { total: typeof data?.total === "number" ? data.total : 0 };
}

export async function createDm(peerId: string) {
  return api.post<ChatThread>("/api/x-live/chats/dm", { peerId });
}

export async function getMessages(chatId: string, page = 1): Promise<{ messages: ChatMessage[] }> {
  const res = await api.get<Record<string, unknown>>(
    withQuery(`/api/x-live/chats/${chatId}/messages`, { page, limit: 50 })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? (data.docs as Record<string, unknown>[])
    : Array.isArray(data?.messages)
    ? (data.messages as Record<string, unknown>[])
    : Array.isArray(data)
    ? (data as Record<string, unknown>[])
    : [];
  return {
    messages: list.map(normalizeChatMessage).reverse(),
  };
}

export async function sendMessage(chatId: string, content: string, replyToMessageId?: string): Promise<ChatMessage> {
  const res = await api.post<Record<string, unknown>>(`/api/x-live/chats/${chatId}/messages`, {
    content,
    replyToMessageId,
  });
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return normalizeChatMessage(data);
}

export async function uploadChatMessage(
  chatId: string,
  file: File,
  content = "",
  mediaType = "image",
  replyToMessageId?: string,
  onProgress?: (pct: number) => void
): Promise<ChatMessage> {
  const form = new FormData();
  form.append("file", file, file.name);
  form.append("content", content || "");
  form.append("mediaType", mediaType);
  form.append("type", mediaType);
  form.append("fileName", file.name);
  form.append("originalName", file.name);
  form.append("filename", file.name);
  if (replyToMessageId) form.append("replyToMessageId", replyToMessageId);
  const res = await uploadChatForm(`/api/x-live/chats/${chatId}/messages/upload`, form, onProgress);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return rememberChatUploadName(normalizeChatMessage(data), file.name);
}

export async function editDmMessage(chatId: string, messageId: string, content: string): Promise<ChatMessage> {
  const res = await api.patch<Record<string, unknown>>(`/api/x-live/chats/${chatId}/messages/${messageId}`, { content });
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return normalizeChatMessage(data);
}

export async function deleteDmMessage(chatId: string, messageId: string) {
  return api.delete(`/api/x-live/chats/${chatId}/messages/${messageId}`);
}

export async function markChatRead(chatId: string) {
  return api.post(`/api/x-live/chats/${chatId}/read`);
}

export async function addDmReaction(chatId: string, messageId: string, emoji: string) {
  return api.post(`/api/x-live/chats/${chatId}/messages/${messageId}/reactions`, { emoji });
}

export async function removeDmReaction(chatId: string, messageId: string, emoji: string) {
  return api.delete(`/api/x-live/chats/${chatId}/messages/${messageId}/reactions`, { emoji });
}

export async function addGroupReaction(groupId: string, messageId: string, emoji: string) {
  return api.post(`/api/x-live/groups/${groupId}/chat/messages/${messageId}/reactions`, { emoji });
}

export async function removeGroupReaction(groupId: string, messageId: string, emoji: string) {
  return api.delete(`/api/x-live/groups/${groupId}/chat/messages/${messageId}/reactions`, { emoji });
}

export type CallCredentials = {
  id: string;
  chatId?: string;
  groupId?: string;
  callerId?: string;
  calleeId?: string;
  type: "audio" | "video";
  status: string;
  channel: string;
  token?: string;
  appId?: string;
  uid?: string | number;
};

export async function startDmCall(chatId: string, callType: "audio" | "video"): Promise<CallCredentials> {
  const res = await api.post<Record<string, unknown>>(`/api/x-live/chats/${chatId}/calls`, { type: callType });
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return {
    id: String(data._id ?? data.id ?? data.callId ?? ""),
    chatId: String(data.chatId ?? chatId),
    callerId: data.callerId ? String(data.callerId) : undefined,
    calleeId: data.calleeId ? String(data.calleeId) : undefined,
    type: callType,
    status: String(data.status ?? "ringing"),
    channel: String(data.channel ?? data.agoraChannel ?? ""),
    token: data.token ? String(data.token) : undefined,
    appId: data.appId ? String(data.appId) : undefined,
    uid: (data.uid as string | number | undefined),
  };
}

export async function getActiveDmCall(chatId: string): Promise<CallCredentials | null> {
  try {
    const res = await api.get<Record<string, unknown>>(`/api/x-live/chats/${chatId}/calls/active`);
    const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
      ? res.data
      : res) as Record<string, unknown>;
    if (!data || (!data._id && !data.id)) return null;
    return {
      id: String(data._id ?? data.id),
      chatId: String(data.chatId ?? chatId),
      callerId: data.callerId ? String(data.callerId) : undefined,
      calleeId: data.calleeId ? String(data.calleeId) : undefined,
      type: (data.type as "audio" | "video") ?? "video",
      status: String(data.status ?? "ringing"),
      channel: String(data.channel ?? data.agoraChannel ?? ""),
      token: data.token ? String(data.token) : undefined,
      appId: data.appId ? String(data.appId) : undefined,
      uid: (data.uid as string | number | undefined),
    };
  } catch {
    return null;
  }
}

export async function acceptDmCall(callId: string): Promise<CallCredentials> {
  const res = await api.post<Record<string, unknown>>(`/api/x-live/chats/calls/${callId}/accept`);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return {
    id: String(data._id ?? data.id ?? callId),
    chatId: data.chatId ? String(data.chatId) : undefined,
    callerId: data.callerId ? String(data.callerId) : undefined,
    calleeId: data.calleeId ? String(data.calleeId) : undefined,
    type: (data.type as "audio" | "video") ?? "video",
    status: String(data.status ?? "accepted"),
    channel: String(data.channel ?? data.agoraChannel ?? ""),
    token: data.token ? String(data.token) : undefined,
    appId: data.appId ? String(data.appId) : undefined,
    uid: (data.uid as string | number | undefined),
  };
}

export async function declineDmCall(callId: string) {
  return api.post(`/api/x-live/chats/calls/${callId}/decline`);
}

export async function endDmCall(callId: string) {
  return api.post(`/api/x-live/chats/calls/${callId}/end`);
}

export async function getGroups(): Promise<{ groups: GroupSummary[] }> {
  const res = await api.get<Record<string, unknown>>("/api/x-live/groups");
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? (data.docs as Record<string, unknown>[])
    : Array.isArray(data?.groups)
    ? (data.groups as Record<string, unknown>[])
    : Array.isArray(data)
    ? (data as Record<string, unknown>[])
    : [];
  return {
    groups: list.map((g) => ({
      id: String(g._id ?? g.id ?? ""),
      name: String(g.name ?? "Group"),
      avatarUrl: (g.iconUrl ?? g.avatarUrl) as string | undefined,
      memberCount: typeof g.memberCount === "number" ? g.memberCount : (Array.isArray(g.members) ? g.members.length : 0),
      lastMessage: previewFromLastMessage(g.lastMessage),
      unreadCount: typeof g.unreadCount === "number" ? g.unreadCount : 0,
    })),
  };
}

export async function discoverGroups(): Promise<{ groups: GroupSummary[] }> {
  const res = await api.get<Record<string, unknown>>("/api/x-live/groups/discover");
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? (data.docs as Record<string, unknown>[])
    : Array.isArray(data?.groups)
    ? (data.groups as Record<string, unknown>[])
    : Array.isArray(data)
    ? (data as Record<string, unknown>[])
    : [];
  return {
    groups: list.map((g) => ({
      id: String(g._id ?? g.id ?? ""),
      name: String(g.name ?? "Group"),
      avatarUrl: (g.iconUrl ?? g.avatarUrl) as string | undefined,
      memberCount: typeof g.memberCount === "number" ? g.memberCount : (Array.isArray(g.members) ? g.members.length : 0),
      lastMessage: previewFromLastMessage(g.lastMessage),
      unreadCount: typeof g.unreadCount === "number" ? g.unreadCount : 0,
    })),
  };
}

export async function createGroup(payload: { name: string; description?: string }): Promise<GroupSummary> {
  const res = await api.post<Record<string, unknown>>("/api/x-live/groups", payload);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return {
    id: String(data._id ?? data.id ?? ""),
    name: String(data.name ?? "Group"),
    avatarUrl: (data.iconUrl ?? data.avatarUrl) as string | undefined,
    memberCount: typeof data.memberCount === "number" ? data.memberCount : 1,
    lastMessage: typeof data.lastMessage === "string" ? data.lastMessage : undefined,
    unreadCount: 0,
  };
}

export async function getGroup(groupId: string): Promise<GroupSummary> {
  const res = await api.get<Record<string, unknown>>(`/api/x-live/groups/${groupId}`);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const members = parseGroupMembers(data.members ?? data.users);
  seedSenderHandles(members);
  return {
    id: String(data._id ?? data.id ?? groupId),
    name: String(data.name ?? "Group"),
    avatarUrl: (data.iconUrl ?? data.avatarUrl) as string | undefined,
    memberCount: typeof data.memberCount === "number" ? data.memberCount : members.length,
    lastMessage: typeof data.lastMessage === "string" ? data.lastMessage : undefined,
    unreadCount: typeof data.unreadCount === "number" ? data.unreadCount : 0,
    members,
  };
}

export async function joinGroupByCode(code: string): Promise<GroupSummary> {
  const res = await api.get<Record<string, unknown>>(`/api/x-live/groups/join/${code}`);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return {
    id: String(data._id ?? data.id ?? ""),
    name: String(data.name ?? "Group"),
    avatarUrl: (data.iconUrl ?? data.avatarUrl) as string | undefined,
    memberCount: typeof data.memberCount === "number" ? data.memberCount : 1,
    lastMessage: undefined,
    unreadCount: 0,
  };
}

export async function getGroupMessages(groupId: string, page = 1): Promise<{ messages: ChatMessage[] }> {
  const res = await api.get<Record<string, unknown>>(
    withQuery(`/api/x-live/groups/${groupId}/chat/messages`, { page, limit: 50 })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? (data.docs as Record<string, unknown>[])
    : Array.isArray(data?.messages)
    ? (data.messages as Record<string, unknown>[])
    : Array.isArray(data)
    ? (data as Record<string, unknown>[])
    : [];
  return {
    messages: await fillMessageHandles(list.map(normalizeChatMessage).reverse()),
  };
}

export async function sendGroupMessage(groupId: string, content: string, replyToMessageId?: string): Promise<ChatMessage> {
  const body: Record<string, unknown> = { content };
  if (replyToMessageId) body.replyToMessageId = replyToMessageId;
  const res = await api.post<Record<string, unknown>>(`/api/x-live/groups/${groupId}/chat/messages`, body);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return (await fillMessageHandles([normalizeChatMessage(data)]))[0];
}

export async function uploadGroupChatMessage(
  groupId: string,
  file: File,
  content = "",
  mediaType = "image",
  replyToMessageId?: string,
  onProgress?: (pct: number) => void
): Promise<ChatMessage> {
  const form = new FormData();
  form.append("file", file, file.name);
  form.append("content", content || "");
  form.append("mediaType", mediaType);
  form.append("type", mediaType);
  form.append("fileName", file.name);
  form.append("originalName", file.name);
  form.append("filename", file.name);
  if (replyToMessageId) form.append("replyToMessageId", replyToMessageId);
  const res = await uploadChatForm(`/api/x-live/groups/${groupId}/chat/messages/upload`, form, onProgress);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return (await fillMessageHandles([rememberChatUploadName(normalizeChatMessage(data), file.name)]))[0];
}

export async function editGroupMessage(groupId: string, messageId: string, content: string): Promise<ChatMessage> {
  const res = await api.patch<Record<string, unknown>>(`/api/x-live/groups/${groupId}/chat/messages/${messageId}`, { content });
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return (await fillMessageHandles([normalizeChatMessage(data)]))[0];
}

export async function deleteGroupMessage(groupId: string, messageId: string) {
  return api.delete(`/api/x-live/groups/${groupId}/chat/messages/${messageId}`);
}

export async function startGroupCall(groupId: string, callType: "audio" | "video"): Promise<CallCredentials> {
  const res = await api.post<Record<string, unknown>>(`/api/x-live/groups/${groupId}/calls`, { type: callType });
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const callId = String(data._id ?? data.id ?? data.callId ?? "");
  let joinData: CallCredentials | null = null;
  if (callId) {
    try {
      joinData = await joinGroupCall(callId);
    } catch {
    }
  }
  return {
    id: callId,
    groupId,
    type: callType,
    status: String(data.status ?? "active"),
    channel: joinData?.channel || String(data.channel ?? data.agoraChannel ?? ""),
    token: joinData?.token,
    appId: joinData?.appId,
    uid: joinData?.uid,
  };
}

export async function joinGroupCall(callId: string): Promise<CallCredentials> {
  const res = await api.post<Record<string, unknown>>(`/api/x-live/groups/calls/${callId}/join`);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return {
    id: String(data._id ?? data.id ?? callId),
    groupId: data.groupId ? String(data.groupId) : undefined,
    type: (data.type as "audio" | "video") ?? "video",
    status: String(data.status ?? "active"),
    channel: String(data.channel ?? data.agoraChannel ?? ""),
    token: data.token ? String(data.token) : undefined,
    appId: data.appId ? String(data.appId) : undefined,
    uid: (data.uid as string | number | undefined),
  };
}

export async function getActiveGroupCall(groupId: string): Promise<CallCredentials | null> {
  try {
    const res = await api.get<Record<string, unknown>>(`/api/x-live/groups/${groupId}/calls/active`);
    const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
      ? res.data
      : res) as Record<string, unknown>;
    if (!data || (!data._id && !data.id)) return null;
    return {
      id: String(data._id ?? data.id),
      groupId: String(data.groupId ?? groupId),
      type: (data.type as "audio" | "video") ?? "video",
      status: String(data.status ?? "active"),
      channel: String(data.channel ?? data.agoraChannel ?? ""),
    };
  } catch {
    return null;
  }
}

export async function leaveGroupCall(callId: string) {
  return api.post(`/api/x-live/groups/calls/${callId}/leave`);
}

export async function endGroupCall(callId: string) {
  return api.post(`/api/x-live/groups/calls/${callId}/end`);
}

export type ChatHistoryHit = {
  id: string;
  href: string;
  title: string;
  preview: string;
  avatarUrl?: string;
  kind: "dm" | "group";
};

export async function searchChatHistory(
  query: string,
  opts: { chats: ChatThread[]; groups: GroupSummary[] },
  onHit: (hit: ChatHistoryHit) => void,
  signal?: AbortSignal
) {
  const needle = query.trim().toLowerCase();
  if (needle.length < 2) return;
  const seen = new Set<string>();

  async function scanPages(
    load: (page: number) => Promise<ChatMessage[]>,
    makeHit: (message: ChatMessage) => ChatHistoryHit
  ) {
    for (let page = 1; page <= 8; page += 1) {
      if (signal?.aborted) return;
      const messages = await load(page);
      if (!messages.length) return;
      for (const message of messages) {
        if (signal?.aborted) return;
        const text = (message.content || "").toLowerCase();
        if (!text.includes(needle)) continue;
        const hit = makeHit(message);
        if (seen.has(hit.id)) continue;
        seen.add(hit.id);
        onHit(hit);
      }
      if (messages.length < 50) return;
    }
  }

  const tasks = [
    ...opts.chats
      .filter((chat) => chat.id)
      .map((chat) => () =>
        scanPages(
          async (page) => (await getMessages(chat.id, page)).messages,
          (message) => ({
            id: `dm:${chat.id}:${message.id}`,
            href: `/chats/${chat.id}`,
            title: `@${publicHandle(chat.peer) || "user"}`,
            preview: message.content,
            avatarUrl: chat.peer?.avatarUrl,
            kind: "dm" as const,
          })
        )
      ),
    ...opts.groups
      .filter((group) => group.id)
      .map((group) => () =>
        scanPages(
          async (page) => (await getGroupMessages(group.id, page)).messages,
          (message) => ({
            id: `group:${group.id}:${message.id}`,
            href: `/groups/${group.id}?name=${encodeURIComponent(group.name || "Group")}`,
            title: group.name || "Group",
            preview: message.content,
            avatarUrl: group.avatarUrl,
            kind: "group" as const,
          })
        )
      ),
  ];

  let cursor = 0;
  async function worker() {
    while (cursor < tasks.length) {
      if (signal?.aborted) return;
      const run = tasks[cursor++];
      try {
        await run();
      } catch {
      }
    }
  }
  await Promise.all([worker(), worker(), worker()]);
}
