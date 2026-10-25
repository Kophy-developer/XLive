"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { Fragment, Suspense, useCallback, useEffect, useRef, useState } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  addGroupReaction,
  deleteGroupMessage,
  editGroupMessage,
  fillMessageHandles,
  getGroup,
  getGroupMessages,
  normalizeChatMessage,
  removeGroupReaction,
  seedSenderHandles,
  sendGroupMessage,
  startGroupCall,
  uploadGroupChatMessage,
} from "@/lib/api/chats";
import { emitGroupCallJoin, emitGroupCallStart, onSocketEvent, socketEvents } from "@/lib/socket";
import { useAuthStore, useCallStore } from "@/lib/stores";
import type { ChatMessage } from "@/lib/types";
import { cloudinaryUrl, cn, handleLabel, playbackVideoUrl, publicHandle } from "@/lib/utils";
import {
  chatDocumentLabel,
  chatImageUrls,
  contentsForPending,
  groupChatBubbles,
  isChatDocumentMessage,
  isChatImageMessage,
  isChatVideoMessage,
  isChatVoiceMessage,
  orderPendingForSend,
  pendingFromFiles,
  revokePendingPreviews,
  visibleChatCaption,
  withChatDayPills,
  type ChatUploadProgress,
  type PendingChatFile,
} from "@/lib/chat-media";
import { ChatPendingBar, ChatUploadOverlay } from "@/components/chat-attach";
import { ChatDayPill, ChatImageCollage, ChatPhotoViewer } from "@/components/chat-image-viewer";
import {
  ArrowLeft,
  Download,
  FileText,
  Image as ImageIcon,
  Music,
  Paperclip,
  Pencil,
  Phone,
  Reply,
  Send,
  Smile,
  Trash2,
  Users,
  Video,
  X,
} from "lucide-react";
import { EmojiStickerPicker, QuickReactionsBar, ReactionChips } from "@/components/chat-reactions";

function isSameMessage(a: ChatMessage, b: ChatMessage): boolean {
  if (a.id && b.id && a.id === b.id) return true;
  const aRawId = (a as unknown as Record<string, unknown>)._id;
  const bRawId = (b as unknown as Record<string, unknown>)._id;
  if (aRawId && bRawId && String(aRawId) === String(bRawId)) return true;
  if (a.id && bRawId && a.id === String(bRawId)) return true;
  if (b.id && aRawId && b.id === String(aRawId)) return true;

  if (
    a.senderId &&
    b.senderId &&
    a.senderId === b.senderId &&
    a.content &&
    b.content &&
    a.content.trim() === b.content.trim() &&
    a.mediaUrl === b.mediaUrl
  ) {
    const timeA = new Date(a.createdAt).getTime();
    const timeB = new Date(b.createdAt).getTime();
    if (!isNaN(timeA) && !isNaN(timeB) && Math.abs(timeA - timeB) < 7000) {
      return true;
    }
  }

  return false;
}

function mergeMessageList(existing: ChatMessage[], incoming: ChatMessage[]): ChatMessage[] {
  const result = [...existing];
  for (const item of incoming) {
    if (!item.id && !item.content && !item.mediaUrl) continue;
    const existingIndex = result.findIndex((m) => isSameMessage(m, item));
    if (existingIndex >= 0) {
      result[existingIndex] = {
        ...result[existingIndex],
        ...item,
        id: item.id || result[existingIndex].id,
        fileName: item.fileName || result[existingIndex].fileName,
        reactions: item.reactions && item.reactions.length > 0 ? item.reactions : result[existingIndex].reactions,
      };
    } else {
      result.push(item);
    }
  }
  return result.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
}

function GroupChatContent() {
  const params = useParams();
  const searchParams = useSearchParams();
  const router = useRouter();

  const groupId = params.groupId as string;
  const currentUserId = useAuthStore((s) => s.user?.id);
  const activeCall = useCallStore((s) => s.activeCall);

  const queryName = searchParams.get("name");
  const queryAvatar = searchParams.get("avatar");

  const [input, setInput] = useState("");
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [uploading, setUploading] = useState(false);
  const [isSending, setIsSending] = useState(false);
  const [uploadError, setUploadError] = useState("");
  const [pendingFiles, setPendingFiles] = useState<PendingChatFile[]>([]);
  const [uploadProgress, setUploadProgress] = useState<ChatUploadProgress | null>(null);
  const [photoViewer, setPhotoViewer] = useState<{ urls: string[]; index: number } | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [activeReactionMsgId, setActiveReactionMsgId] = useState<string | null>(null);

  const [replyingTo, setReplyingTo] = useState<ChatMessage | null>(null);
  const [editingMessage, setEditingMessage] = useState<{ id: string; content: string } | null>(null);

  const bottomRef = useRef<HTMLDivElement>(null);
  const chatContainerRef = useRef<HTMLDivElement>(null);
  const mediaInputRef = useRef<HTMLInputElement>(null);
  const docInputRef = useRef<HTMLInputElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const sendingRef = useRef(false);
  const isInitialLoadRef = useRef(true);

  const scrollToBottomIfNear = useCallback((force = false) => {
    const container = chatContainerRef.current;
    if (!container) return;
    const isNearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 220;
    if (force || isNearBottom || isInitialLoadRef.current) {
      setTimeout(() => {
        bottomRef.current?.scrollIntoView({ behavior: isInitialLoadRef.current ? "auto" : "smooth" });
        isInitialLoadRef.current = false;
      }, 50);
    }
  }, []);

  const { data: group } = useQuery({
    queryKey: ["group", groupId],
    queryFn: () => getGroup(groupId),
  });

  const { data, isLoading, refetch: refetchMessages } = useQuery({
    queryKey: ["group-messages", groupId],
    queryFn: () => getGroupMessages(groupId),
    refetchInterval: 3000,
    refetchIntervalInBackground: false,
    refetchOnWindowFocus: true,
  });

  const groupName = queryName || group?.name || "Group Chat";
  const groupAvatarUrl = queryAvatar || group?.avatarUrl;
  const memberCount = group?.memberCount;

  useEffect(() => {
    if (group?.members) seedSenderHandles(group.members);
  }, [group?.members]);

  function memberHandle(message?: { senderId?: string; senderName?: string } | null): string {
    if (!message) return "";
    const fromMessage = publicHandle(message.senderName);
    if (fromMessage) return fromMessage;
    const fromMember = group?.members?.find((m) => m.id === message.senderId);
    return publicHandle(fromMember) || "";
  }

  useEffect(() => {
    const offReaction = onSocketEvent<{ groupId?: string }>(socketEvents.groupMessageReaction, (d) => {
      if (!d?.groupId || d.groupId === groupId) {
        refetchMessages();
      }
    });

    const offReceived = onSocketEvent<unknown>(socketEvents.groupMessage, (raw) => {
      void (async () => {
        const [msg] = await fillMessageHandles([normalizeChatMessage(raw)]);
        if (!msg.chatId || msg.chatId === groupId) {
          setMessages((prev) => mergeMessageList(prev, [msg]));
          scrollToBottomIfNear(msg.senderId === currentUserId);
          refetchMessages();
        }
      })();
    });

    const offEdited = onSocketEvent<unknown>(socketEvents.groupMessageEdited, (raw) => {
      void (async () => {
        const [msg] = await fillMessageHandles([normalizeChatMessage(raw)]);
        if (!msg.chatId || msg.chatId === groupId) {
          setMessages((prev) =>
            prev.map((m) =>
              isSameMessage(m, msg) ? { ...m, ...msg, editedAt: msg.editedAt || new Date().toISOString() } : m
            )
          );
          refetchMessages();
        }
      })();
    });

    const offDeleted = onSocketEvent<unknown>(socketEvents.groupMessageDeleted, (raw) => {
      const d = (Array.isArray(raw) ? raw[0] : raw) as Record<string, unknown> | null;
      const targetGroupId = String(d?.groupId ?? d?.chatId ?? "");
      if (!targetGroupId || targetGroupId === groupId) {
        const deletedId = String(d?.messageId ?? d?.id ?? d?._id ?? "");
        if (deletedId) {
          setMessages((prev) =>
            prev.filter((m) => m.id !== deletedId && (m as unknown as Record<string, unknown>)._id !== deletedId)
          );
        }
        refetchMessages();
      }
    });

    return () => {
      offReaction();
      offReceived();
      offEdited();
      offDeleted();
    };
  }, [groupId, currentUserId, refetchMessages, scrollToBottomIfNear]);

  useEffect(() => {
    if (data?.messages) {
      setMessages((prev) => mergeMessageList(prev, data.messages));
      scrollToBottomIfNear();
    }
  }, [data, scrollToBottomIfNear]);

  async function handleToggleReaction(messageId: string, emoji: string) {
    setActiveReactionMsgId(null);
    setMessages((prev) =>
      prev.map((msg) => {
        if (msg.id !== messageId) return msg;
        const existing = msg.reactions || [];
        const hasReacted = existing.some(
          (r) =>
            r.emoji === emoji &&
            ((r.userId && r.userId === currentUserId) || (r.userIds && currentUserId && r.userIds.includes(currentUserId)))
        );

        let nextReactions = [...existing];
        if (hasReacted) {
          nextReactions = nextReactions
            .map((r) => {
              if (r.emoji !== emoji) return r;
              const nextCount = Math.max(0, (r.count || 1) - 1);
              const nextUsers = (r.userIds || []).filter((u) => u !== currentUserId);
              return { ...r, count: nextCount, userIds: nextUsers };
            })
            .filter((r) => (r.count || 0) > 0);
        } else {
          const matchIdx = nextReactions.findIndex((r) => r.emoji === emoji);
          if (matchIdx >= 0) {
            const current = nextReactions[matchIdx];
            nextReactions[matchIdx] = {
              ...current,
              count: (current.count || 0) + 1,
              userIds: [...(current.userIds || []), currentUserId || ""],
            };
          } else {
            nextReactions.push({
              emoji,
              count: 1,
              userId: currentUserId,
              userIds: [currentUserId || ""],
            });
          }
        }
        return { ...msg, reactions: nextReactions };
      })
    );

    try {
      const msg = messages.find((m) => m.id === messageId);
      const hasReacted = (msg?.reactions || []).some(
        (r) =>
          r.emoji === emoji &&
          ((r.userId && r.userId === currentUserId) || (r.userIds && currentUserId && r.userIds.includes(currentUserId)))
      );
      if (hasReacted) {
        await removeGroupReaction(groupId, messageId, emoji);
      } else {
        await addGroupReaction(groupId, messageId, emoji);
      }
    } catch {
      refetchMessages();
    }
  }

  async function sendPendingFiles(files = pendingFiles) {
    if (!files.length || uploading) return false;
    setUploading(true);
    setUploadError("");
    const replyId = replyingTo?.id;
    setReplyingTo(null);
    const items = orderPendingForSend(files);
    const contents = contentsForPending(items);
    try {
      for (let i = 0; i < items.length; i += 1) {
        const item = items[i];
        setUploadProgress({ index: i + 1, total: items.length, name: item.file.name, pct: 8 });
        const msg = await uploadGroupChatMessage(
          groupId,
          item.file,
          contents[i],
          item.mediaType,
          replyId,
          (pct) => setUploadProgress({ index: i + 1, total: items.length, name: item.file.name, pct })
        );
        setMessages((prev) => mergeMessageList(prev, [msg]));
        scrollToBottomIfNear(true);
      }
      revokePendingPreviews(items);
      setPendingFiles([]);
      setUploadProgress(null);
      refetchMessages();
    } catch (err) {
      setUploadError((err as Error).message || "Upload failed");
      return false;
    } finally {
      setUploading(false);
    }
    return true;
  }

  async function handleSend(e: React.FormEvent) {
    e.preventDefault();
    if (sendingRef.current || isSending || uploading) return;

    if (pendingFiles.length) {
      const composer = input.trim();
      let filesToSend = pendingFiles;
      if (composer) {
        if (pendingFiles.length === 1 && !pendingFiles[0].caption?.trim()) {
          filesToSend = [{ ...pendingFiles[0], caption: composer }];
          setPendingFiles(filesToSend);
        }
        setInput("");
      }
      const ok = await sendPendingFiles(filesToSend);
      if (!ok) return;
      return;
    }

    if (!input.trim()) return;
    const text = input.trim();

    if (editingMessage) {
      const targetId = editingMessage.id;
      setEditingMessage(null);
      setInput("");
      setMessages((prev) =>
        prev.map((m) => (m.id === targetId ? { ...m, content: text, editedAt: new Date().toISOString() } : m))
      );
      try {
        await editGroupMessage(groupId, targetId, text);
        refetchMessages();
      } catch {
        refetchMessages();
      }
      return;
    }

    const replyId = replyingTo?.id;
    setReplyingTo(null);
    setInput("");
    sendingRef.current = true;
    setIsSending(true);

    try {
      const msg = await sendGroupMessage(groupId, text, replyId);
      setMessages((prev) => mergeMessageList(prev, [msg]));
      scrollToBottomIfNear(true);
      refetchMessages();
    } catch {
      setInput(text);
    } finally {
      sendingRef.current = false;
      setIsSending(false);
    }
  }

  async function handleDeleteMessage(messageId: string) {
    if (!confirm("Are you sure you want to delete this message?")) return;
    setMessages((prev) => prev.filter((m) => m.id !== messageId && (m as unknown as Record<string, unknown>)._id !== messageId));
    try {
      await deleteGroupMessage(groupId, messageId);
      refetchMessages();
    } catch {
      refetchMessages();
    }
  }

  function handleFileUpload(e: React.ChangeEvent<HTMLInputElement>, kind: "media" | "document") {
    const files = e.target.files;
    if (!files?.length) return;
    const picked = pendingFromFiles(files, kind);
    if (!picked.length) {
      setUploadError(kind === "media" ? "Use the paperclip to send documents" : "Use the photo icon to send images or videos");
      e.target.value = "";
      return;
    }
    setUploadError("");
    setPendingFiles((prev) => [...prev, ...picked]);
    e.target.value = "";
  }

  async function startCall(type: "audio" | "video") {
    try {
      const call = await startGroupCall(groupId, type);
      if (call.id) {
        emitGroupCallStart(groupId, type, call.id);
        emitGroupCallJoin(call.id);
        if (call.token) {
          sessionStorage.setItem(`group_call_${call.id}`, JSON.stringify(call));
        }
        router.push(`/groups/${groupId}/call?callId=${call.id}&type=${type}`);
      }
    } catch (err) {
      alert((err as Error).message || "Failed to start group call");
    }
  }

  return (
    <div className="flex h-[calc(100dvh-3.5rem)] md:h-dvh flex-col bg-[#0b0b12]">
      <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-white/10 bg-[#12121e]/95 px-4 backdrop-blur-xl">
        <div className="flex items-center gap-3 min-w-0">
          <Link
            href="/chats"
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-white/10 bg-white/5 text-zinc-300 transition hover:bg-white/10 hover:text-white active:scale-95 shrink-0"
          >
            <ArrowLeft className="h-4 w-4" />
          </Link>

          <div className="relative shrink-0">
            {groupAvatarUrl ? (
              <img
                src={cloudinaryUrl(groupAvatarUrl, "c_fill,w_96,h_96,g_auto")}
                alt=""
                className="h-10 w-10 rounded-2xl object-cover border border-white/10"
              />
            ) : (
              <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-gradient-to-br from-brand-purple/20 to-brand-sky/20 font-sans text-xs font-bold text-white shadow-md">
                {groupName.charAt(0).toUpperCase()}
              </div>
            )}
          </div>

          <div className="min-w-0">
            <h1 className="font-sans text-base font-bold text-white tracking-tight truncate">
              {groupName}
            </h1>
            <p className="font-sans text-[11px] text-zinc-400 flex items-center gap-1 truncate">
              <Users className="h-3 w-3 shrink-0 text-brand-purple" />
              <span>{memberCount ? `${memberCount} members` : "Group conversation"}</span>
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 shrink-0">
          <button
            type="button"
            onClick={() => startCall("audio")}
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-white/10 bg-white/5 text-zinc-300 transition hover:bg-white/10 hover:text-white active:scale-95"
            title="Group Voice Call"
          >
            <Phone className="h-4 w-4" />
          </button>
          <button
            type="button"
            onClick={() => startCall("video")}
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-white/10 bg-white/5 text-zinc-300 transition hover:bg-white/10 hover:text-white active:scale-95"
            title="Group Video Call"
          >
            <Video className="h-4 w-4" />
          </button>
        </div>
      </header>

      {activeCall && activeCall.groupId === groupId && (
        <div className="mx-4 mt-2 flex items-center justify-between rounded-2xl border border-emerald-500/30 bg-emerald-500/10 px-4 py-2.5 backdrop-blur-xl animate-in slide-in-from-top-2">
          <div className="flex items-center gap-2.5">
            <span className="relative flex h-2.5 w-2.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500" />
            </span>
            <span className="text-xs font-bold text-white">Group call in progress</span>
          </div>
          <Link
            href={`/groups/${groupId}/call?callId=${activeCall.callId}&type=${activeCall.callType}`}
            className="rounded-xl brand-gradient px-3 py-1 text-xs font-bold text-white shadow-sm hover:opacity-95"
          >
            Join Call
          </Link>
        </div>
      )}

      <div ref={chatContainerRef} className="flex-1 space-y-3 overflow-y-auto p-4">
        {isLoading ? (
          <div className="flex justify-center py-20">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        ) : !messages.length ? (
          <div className="flex flex-col items-center justify-center py-24 text-center">
            <p className="font-sans text-sm font-semibold text-white">No messages yet in this group</p>
            <p className="mt-1 text-xs text-muted">Say hello to other members</p>
          </div>
        ) : (
          withChatDayPills(groupChatBubbles(messages)).map(({ block, dayLabel }) => {
            const album = block.kind === "album" ? block.messages : null;
            const m = block.kind === "album" ? block.messages[block.messages.length - 1] : block.message;
            const isMine = currentUserId ? m.senderId === currentUserId : false;
            const hasMedia = Boolean(m.mediaUrl);
            const isImage = isChatImageMessage(m);
            const isVideo = isChatVideoMessage(m);
            const isDoc = isChatDocumentMessage(m);
            const isVoice = isChatVoiceMessage(m);
            const caption = visibleChatCaption(m.content);
            const imageUrls = album ? chatImageUrls(album) : hasMedia && isImage && m.mediaUrl ? [m.mediaUrl] : [];

            const quotedMessage = m.replyTo || (m.replyToMessageId ? messages.find((x) => x.id === m.replyToMessageId) : null);
            const senderHandle = memberHandle(m);
            const quotedHandle = quotedMessage ? memberHandle(quotedMessage) : "";

            return (
              <Fragment key={m.id}>
                {dayLabel ? <ChatDayPill label={dayLabel} /> : null}
              <div
                id={`msg-${m.id}`}
                className={cn("relative group flex flex-col transition-all duration-300", isMine ? "items-end" : "items-start")}
              >
                <div className="relative">
                  {activeReactionMsgId === m.id && (
                    <>
                      <div
                        className="fixed inset-0 z-30"
                        onClick={() => setActiveReactionMsgId(null)}
                      />
                      <div className="relative z-40">
                        <QuickReactionsBar
                          onSelectEmoji={(emoji) => handleToggleReaction(m.id, emoji)}
                          alignRight={isMine}
                        />
                      </div>
                    </>
                  )}

                  <div className={cn("flex items-center gap-1.5", isMine ? "flex-row-reverse" : "flex-row")}>
                    <div
                      className={cn(
                        "max-w-[85%] sm:max-w-[70%] overflow-hidden rounded-2xl shadow-sm transition",
                        isMine
                          ? "rounded-br-sm brand-gradient text-white"
                          : "rounded-bl-sm border border-border/60 bg-surface/90 text-foreground"
                      )}
                    >
                      {!isMine && senderHandle && (
                        <p className="px-3.5 pt-2 text-[11px] font-bold text-brand-purple">
                          {handleLabel(senderHandle)}
                        </p>
                      )}

                      {quotedMessage && (
                        <div
                          onClick={() => {
                            const el = document.getElementById(`msg-${quotedMessage.id || m.replyToMessageId}`);
                            if (el) {
                              el.scrollIntoView({ behavior: "smooth", block: "center" });
                              el.classList.add("ring-2", "ring-brand-purple");
                              setTimeout(() => el.classList.remove("ring-2", "ring-brand-purple"), 1500);
                            }
                          }}
                          className={cn(
                            "mx-2.5 mt-2 cursor-pointer rounded-xl border-l-4 p-2 text-left transition",
                            isMine
                              ? "border-white/80 bg-black/25 hover:bg-black/35"
                              : "border-brand-purple bg-white/5 hover:bg-white/10"
                          )}
                        >
                          <p
                            className={cn(
                              "font-sans text-[11px] font-bold truncate",
                              isMine ? "text-white" : "text-brand-purple"
                            )}
                          >
                            {quotedHandle ? handleLabel(quotedHandle) : "message"}
                          </p>
                          <p
                            className={cn(
                              "font-sans text-xs truncate",
                              isMine ? "text-white/80" : "text-zinc-300"
                            )}
                          >
                            {quotedMessage.content || (quotedMessage.mediaType ? `[${quotedMessage.mediaType}]` : "Attachment")}
                          </p>
                        </div>
                      )}

                      {imageUrls.length ? (
                        <ChatImageCollage
                          urls={imageUrls}
                          onOpen={(index) => setPhotoViewer({ urls: imageUrls, index })}
                        />
                      ) : null}

                      {hasMedia && isVideo && (
                        <video
                          src={playbackVideoUrl(m.mediaUrl)}
                          controls
                          className="max-h-80 w-full bg-black rounded-lg"
                        />
                      )}

                      {hasMedia && isVoice && (
                        <div className="flex items-center gap-2 p-3">
                          <Music className="h-5 w-5 shrink-0 opacity-80" />
                          <audio src={m.mediaUrl} controls className="h-8 max-w-[220px]" />
                        </div>
                      )}

                      {hasMedia && isDoc && (
                        <a
                          href={m.mediaUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          download
                          className={cn(
                            "flex items-center gap-3 p-3 text-xs font-medium transition",
                            isMine ? "hover:bg-white/10" : "hover:bg-surface-hover"
                          )}
                        >
                          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-black/10">
                            <FileText className="h-5 w-5" />
                          </div>
                          <div className="min-w-0 flex-1">
                            <p className="truncate font-semibold">{chatDocumentLabel(m)}</p>
                            <span className="text-[10px] opacity-75">Tap to download</span>
                          </div>
                          <Download className="h-4 w-4 shrink-0 opacity-80" />
                        </a>
                      )}

                      {caption && !isDoc ? (
                        <p className="break-words px-3.5 py-2 text-sm leading-relaxed font-sans">
                          {caption}
                        </p>
                      ) : null}

                      <div
                        className={cn(
                          "flex items-center justify-end gap-1.5 px-3 pb-1.5 text-[10px]",
                          isMine ? "text-white/75" : "text-muted"
                        )}
                      >
                        {m.editedAt && (
                          <span className="italic text-[9px] opacity-75">edited</span>
                        )}
                        <span>
                          {new Date(m.createdAt).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                        </span>
                      </div>
                    </div>

                    <div
                      className={cn(
                        "flex items-center gap-1 rounded-full border border-white/10 bg-[#161622]/95 px-1 py-0.5 backdrop-blur-md shadow-lg transition-all duration-150",
                        activeReactionMsgId === m.id
                          ? "opacity-100 ring-1 ring-brand-purple/50"
                          : "opacity-40 hover:opacity-100 group-hover:opacity-100"
                      )}
                    >
                      <button
                        type="button"
                        onClick={() => setActiveReactionMsgId(activeReactionMsgId === m.id ? null : m.id)}
                        className={cn(
                          "flex h-7 w-7 items-center justify-center rounded-full text-zinc-300 hover:text-white hover:bg-white/10 active:scale-95 transition",
                          activeReactionMsgId === m.id && "text-brand-purple bg-brand-purple/20"
                        )}
                        title="React with emoji"
                      >
                        <Smile className="h-4 w-4" />
                      </button>

                      <button
                        type="button"
                        onClick={() => {
                          setActiveReactionMsgId(null);
                          setReplyingTo(m);
                          inputRef.current?.focus();
                        }}
                        className="flex h-7 w-7 items-center justify-center rounded-full text-zinc-300 hover:text-white hover:bg-white/10 active:scale-95 transition"
                        title="Reply"
                      >
                        <Reply className="h-4 w-4" />
                      </button>

                      {isMine && m.content && !hasMedia && (
                        <button
                          type="button"
                          onClick={() => {
                            setActiveReactionMsgId(null);
                            setEditingMessage({ id: m.id, content: m.content });
                            setInput(m.content);
                            inputRef.current?.focus();
                          }}
                          className="flex h-7 w-7 items-center justify-center rounded-full text-zinc-300 hover:text-white hover:bg-white/10 active:scale-95 transition"
                          title="Edit"
                        >
                          <Pencil className="h-3.5 w-3.5" />
                        </button>
                      )}

                      {isMine && (
                        <button
                          type="button"
                          onClick={() => handleDeleteMessage(m.id)}
                          className="flex h-7 w-7 items-center justify-center rounded-full text-zinc-300 hover:text-red-400 hover:bg-red-500/10 active:scale-95 transition"
                          title="Delete"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                        </button>
                      )}
                    </div>
                  </div>
                </div>

                <ReactionChips
                  reactions={m.reactions}
                  currentUserId={currentUserId}
                  onToggleReaction={(emoji) => handleToggleReaction(m.id, emoji)}
                />
              </div>
              </Fragment>
            );
          })
        )}
        <div ref={bottomRef} />
      </div>

      {photoViewer ? (
        <ChatPhotoViewer
          urls={photoViewer.urls}
          index={photoViewer.index}
          onClose={() => setPhotoViewer(null)}
          onIndex={(index) => setPhotoViewer((prev) => (prev ? { ...prev, index } : prev))}
        />
      ) : null}

      {uploadError && (
        <div className="mx-4 mb-2 flex items-center justify-between rounded-2xl border border-red-500/30 bg-red-500/10 px-4 py-2 text-xs font-semibold text-red-400 backdrop-blur-xl">
          <span>{uploadError}</span>
          <button
            type="button"
            onClick={() => setUploadError("")}
            className="ml-2 text-red-300 hover:text-white"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      {replyingTo && (
        <div className="flex items-center justify-between gap-3 border-t border-white/10 bg-[#161626]/95 px-4 py-2.5 backdrop-blur-xl animate-in slide-in-from-bottom-2">
          <div className="flex items-center gap-2.5 min-w-0 border-l-2 border-brand-purple pl-3">
            <Reply className="h-4 w-4 text-brand-purple shrink-0" />
            <div className="min-w-0">
              <p className="font-sans text-[11px] font-bold text-brand-purple truncate">
                Replying to {memberHandle(replyingTo) ? handleLabel(memberHandle(replyingTo)) : "message"}
              </p>
              <p className="font-sans text-xs text-zinc-300 truncate">
                {replyingTo.content || (replyingTo.mediaType ? `[${replyingTo.mediaType}]` : "Attachment")}
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={() => setReplyingTo(null)}
            className="rounded-full p-1 text-zinc-400 hover:bg-white/10 hover:text-white transition"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      {editingMessage && (
        <div className="flex items-center justify-between gap-3 border-t border-white/10 bg-brand-purple/15 px-4 py-2.5 backdrop-blur-xl animate-in slide-in-from-bottom-2">
          <div className="flex items-center gap-2.5 min-w-0 border-l-2 border-brand-purple pl-3">
            <Pencil className="h-4 w-4 text-brand-purple shrink-0" />
            <div className="min-w-0">
              <p className="font-sans text-[11px] font-bold text-brand-purple">
                Editing message
              </p>
              <p className="font-sans text-xs text-zinc-300 truncate">
                {editingMessage.content}
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={() => {
              setEditingMessage(null);
              setInput("");
            }}
            className="rounded-full p-1 text-zinc-400 hover:bg-white/10 hover:text-white transition"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      <ChatUploadOverlay progress={uploadProgress} />
      <ChatPendingBar
        items={pendingFiles}
        disabled={uploading}
        onCaption={(key, caption) =>
          setPendingFiles((prev) => prev.map((item) => (item.key === key ? { ...item, caption } : item)))
        }
        onRemove={(key) =>
          setPendingFiles((prev) => {
            const next = prev.filter((item) => item.key !== key);
            const removed = prev.find((item) => item.key === key);
            if (removed?.previewUrl) URL.revokeObjectURL(removed.previewUrl);
            return next;
          })
        }
      />

      <form onSubmit={handleSend} className="relative sticky bottom-0 z-10 flex items-center gap-2 border-t border-border/80 bg-surface/95 p-3 backdrop-blur-xl">
        <EmojiStickerPicker
          isOpen={pickerOpen}
          onClose={() => setPickerOpen(false)}
          onSelectEmoji={(emoji) => {
            setInput((prev) => prev + emoji);
          }}
          onSelectSticker={async (sticker) => {
            setPickerOpen(false);
            const replyId = replyingTo?.id;
            setReplyingTo(null);
            try {
              const msg = await sendGroupMessage(groupId, sticker, replyId);
              setMessages((prev) => mergeMessageList(prev, [msg]));
              scrollToBottomIfNear(true);
              refetchMessages();
            } catch {
              setInput(sticker);
            }
          }}
        />

        <input
          ref={mediaInputRef}
          type="file"
          accept="image/*,video/*"
          multiple
          className="hidden"
          onChange={(e) => handleFileUpload(e, "media")}
          disabled={uploading || isSending}
        />
        <input
          ref={docInputRef}
          type="file"
          accept=".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv,.zip,.rar,.7z,.json,.mp3,.wav,.aac,.ogg,.m4a,.epub,.rtf"
          multiple
          className="hidden"
          onChange={(e) => handleFileUpload(e, "document")}
          disabled={uploading || isSending}
        />
        <Button
          type="button"
          variant="ghost"
          size="icon"
          onClick={() => mediaInputRef.current?.click()}
          disabled={uploading || isSending}
          className="shrink-0 rounded-xl hover:bg-surface-hover"
          title="Photo or video"
        >
          <ImageIcon className="h-5 w-5 text-muted hover:text-foreground" />
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="icon"
          onClick={() => docInputRef.current?.click()}
          disabled={uploading || isSending}
          className="shrink-0 rounded-xl hover:bg-surface-hover"
          title="Document"
        >
          <Paperclip className="h-5 w-5 text-muted hover:text-foreground" />
        </Button>

        <Button
          type="button"
          variant="ghost"
          size="icon"
          onClick={() => setPickerOpen((prev) => !prev)}
          disabled={uploading || isSending}
          className={cn("shrink-0 rounded-xl hover:bg-surface-hover", pickerOpen && "text-brand-purple bg-brand-purple/15")}
        >
          <Smile className="h-5 w-5" />
        </Button>

        <Input
          ref={inputRef}
          placeholder={
            editingMessage
              ? "Edit your message…"
              : replyingTo
              ? `Reply to ${memberHandle(replyingTo) ? handleLabel(memberHandle(replyingTo)) : "message"}…`
              : uploading
              ? "Uploading attachment…"
              : isSending
              ? "Sending…"
              : "Write a message…"
          }
          value={input}
          onChange={(e) => setInput(e.target.value)}
          disabled={uploading || isSending}
          className="flex-1 rounded-xl bg-surface-hover/60 border-border/60 focus-visible:ring-brand-purple font-sans text-sm"
        />

        <Button
          type="submit"
          disabled={(!input.trim() && !pendingFiles.length) || uploading || isSending}
          className="shrink-0 rounded-xl brand-gradient px-4 font-semibold text-white shadow-md shadow-brand-purple/20 transition hover:opacity-95 disabled:opacity-40"
        >
          {editingMessage ? (
            <span className="font-sans text-xs font-bold">Save</span>
          ) : (
            <Send className="h-4 w-4" />
          )}
        </Button>
      </form>
    </div>
  );
}

export default function GroupChatPage() {
  return (
    <AuthGuard>
      <Suspense
        fallback={
          <div className="flex h-dvh items-center justify-center bg-black">
            <div className="h-8 w-8 animate-pulse rounded-full brand-gradient" />
          </div>
        }
      >
        <GroupChatContent />
      </Suspense>
    </AuthGuard>
  );
}
