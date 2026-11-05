import { io, Socket } from "socket.io-client";
import { config } from "./config";
import { session } from "./session";

let socket: Socket | null = null;
let currentToken: string | null = null;

export function getSocket(): Socket | null {
  return socket;
}

export function connectSocket(): Socket | null {
  const token = session.getJwt();
  if (!token) {
    if (socket) {
      socket.disconnect();
      socket = null;
      currentToken = null;
    }
    return null;
  }
  if (socket && currentToken === token) {
    if (socket.disconnected) {
      socket.connect();
    }
    return socket;
  }
  if (socket) {
    socket.disconnect();
  }
  currentToken = token;
  socket = io(config.wsUrl, {
    auth: { token },
    extraHeaders: {
      Authorization: `Bearer ${token}`,
    },
    transports: ["websocket", "polling"],
    autoConnect: true,
    reconnection: true,
    reconnectionAttempts: Infinity,
    reconnectionDelay: 1000,
    reconnectionDelayMax: 5000,
  });
  return socket;
}

export function disconnectSocket() {
  if (socket) {
    socket.disconnect();
    socket = null;
    currentToken = null;
  }
}

export function onSocketEvent<T = unknown>(event: string, handler: (data: T) => void) {
  const s = connectSocket();
  if (!s) return () => {};
  const wrapped = (...args: unknown[]) => {
    const first = args[0];
    const data = Array.isArray(first) && first.length === 1 ? first[0] : first;
    handler(data as T);
  };
  s.on(event, wrapped);
  return () => {
    s.off(event, wrapped);
  };
}

export function emitSocket(event: string, payload?: unknown) {
  const s = connectSocket();
  s?.emit(event, payload);
}

export function emitSocketAck<T = unknown>(
  event: string,
  payload?: unknown
): Promise<T> {
  return new Promise((resolve, reject) => {
    const s = connectSocket();
    if (!s) {
      reject(new Error("Not connected"));
      return;
    }
    s.emit(event, payload, (response: T) => resolve(response));
  });
}

export const socketEvents = {
  connected: "xlive_connected",
  error: "xlive_error",
  presence: "user_presence_changed",
  streamViewers: "stream_viewers",
  viewerCount: "viewer_count_updated",
  streamEnded: "stream_ended",
  streamChat: "stream_chat_message",
  giftSent: "gift_sent",
  streamGift: "stream_gift_received",
  transcript: "stream_transcript",
  transcriptHistory: "stream_transcript_history",
  messageReceived: "message_received",
  messageEdited: "message_edited",
  messageDeleted: "message_deleted",
  unreadUpdated: "unread_updated",
  messageReaction: "message_reaction",
  groupMessageReaction: "group_message_reaction",
  groupMessage: "group_message_received",
  groupMessageEdited: "group_message_edited",
  groupMessageDeleted: "group_message_deleted",
  dmCallIncoming: "dm_call_incoming",
  dmCallAccepted: "dm_call_accepted",
  dmCallDeclined: "dm_call_declined",
  dmCallEnded: "dm_call_ended",
  streamInviteIncoming: "stream_invite_incoming",
  streamInviteAccepted: "stream_invite_accepted",
  streamInviteDeclined: "stream_invite_declined",
  groupCallStarted: "group_call_started",
  groupCallJoined: "group_call_joined",
  groupCallLeft: "group_call_left",
  groupCallEnded: "group_call_ended",
  notificationCreated: "notification_created",
  billingTick: "stream:billingTick",
  viewerMuted: "stream:viewerMuted",
  viewerUnmuted: "stream:viewerUnmuted",
  talkBackGranted: "stream:talkBackGranted",
  talkBackRevoked: "stream:talkBackRevoked",
  viewerRemoved: "viewer_removed",
} as const;

export async function grantTalkBack(streamId: string, userId: string) {
  const res = await emitSocketAck<Record<string, unknown>>("stream:grantTalkBack", { streamId, userId });
  return res?.ok === true;
}

export async function revokeTalkBack(streamId: string, userId: string) {
  const res = await emitSocketAck<Record<string, unknown>>("stream:revokeTalkBack", { streamId, userId });
  return res?.ok === true;
}

export async function muteStreamViewer(streamId: string, userId: string) {
  const res = await emitSocketAck<Record<string, unknown>>("stream:muteViewer", { streamId, userId });
  return res?.ok === true;
}

export async function unmuteStreamViewer(streamId: string, userId: string) {
  const res = await emitSocketAck<Record<string, unknown>>("stream:unmuteViewer", { streamId, userId });
  return res?.ok === true;
}

export async function removeStreamViewer(streamId: string, userId: string) {
  const res = await emitSocketAck<Record<string, unknown>>("remove_viewer", { streamId, userId });
  return res?.ok === true;
}

export async function requestStreamViewers(streamId: string) {
  await emitSocketAck("stream:getViewers", { streamId }).catch(() => {});
}

export function emitDmCallStart(
  chatId: string,
  callType: string,
  callId?: string,
  extra?: {
    calleeId?: string;
    callerName?: string;
    callerAvatar?: string;
  }
) {
  emitSocket("dm_call_start", {
    chatId,
    callType,
    type: callType,
    ...(callId ? { callId, id: callId } : {}),
    ...(extra?.calleeId ? { calleeId: extra.calleeId, recipientId: extra.calleeId, toUserId: extra.calleeId } : {}),
    ...(extra?.callerName ? { callerName: extra.callerName, peerName: extra.callerName } : {}),
    ...(extra?.callerAvatar ? { callerAvatar: extra.callerAvatar, avatarUrl: extra.callerAvatar } : {}),
  });
}

export function emitDmCallAccept(callId: string) {
  emitSocket("dm_call_accept", { callId });
}

export function emitDmCallDecline(callId: string) {
  emitSocket("dm_call_decline", { callId });
}

export function emitDmCallEnd(callId: string) {
  emitSocket("dm_call_end", { callId });
}

export function emitGroupCallStart(groupId: string, arg1?: string, arg2?: string) {
  let callId: string | undefined;
  let callType: string | undefined;
  if (arg1 === "audio" || arg1 === "video") {
    callType = arg1;
    callId = arg2;
  } else {
    callId = arg1;
    callType = arg2;
  }
  emitSocket("group_call_start", {
    groupId,
    ...(callId ? { callId, id: callId } : {}),
    ...(callType ? { callType, type: callType } : {}),
  });
}

export function emitGroupCallJoin(callId: string) {
  emitSocket("group_call_join", { callId });
}

export function emitGroupCallLeave(callId: string) {
  emitSocket("group_call_leave", { callId });
}

export function emitGroupCallEnd(callId: string) {
  emitSocket("group_call_end", { callId });
}
