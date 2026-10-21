import { api, withQuery } from "./client";
import { isReactionComment } from "../comment-emoji";
import type { MediaComment } from "../types";

export function mediaTargetType(type?: string): "clip" | "video" {
  return type === "clip" ? "clip" : "video";
}

export function normalizeComment(input: unknown): MediaComment | null {
  const raw = (Array.isArray(input) ? input[0] : input) as Record<string, unknown> | null;
  if (!raw || typeof raw !== "object") return null;
  const doc = (
    raw.comment && typeof raw.comment === "object"
      ? raw.comment
      : raw.data && typeof raw.data === "object"
      ? raw.data
      : raw.doc && typeof raw.doc === "object"
      ? raw.doc
      : raw
  ) as Record<string, unknown>;
  const author = (
    doc.author && typeof doc.author === "object"
      ? doc.author
      : doc.user && typeof doc.user === "object"
      ? doc.user
      : doc.sender && typeof doc.sender === "object"
      ? doc.sender
      : {}
  ) as Record<string, unknown>;
  const id = String(doc._id ?? doc.id ?? raw._id ?? raw.id ?? "");
  const content = String(doc.content ?? doc.text ?? doc.body ?? "");
  if (!id && !content) return null;
  return {
    id: id || `tmp-${Date.now()}`,
    content,
    authorId: String(author.id ?? author._id ?? doc.authorId ?? doc.userId ?? "") || undefined,
    authorName: String(
      author.username ?? author.handle ?? doc.username ?? author.displayName ?? doc.authorName ?? "user"
    ).replace(/^@/, ""),
    authorAvatarUrl: (author.avatarUrl ?? author.avatar ?? doc.authorAvatarUrl ?? doc.avatarUrl) as string | undefined,
    createdAt: doc.createdAt ? String(doc.createdAt) : undefined,
    parentId: (doc.parentId ?? doc.parentCommentId) as string | undefined,
  };
}

export async function listComments(targetType: string, targetId: string, page = 1, limit = 50) {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/comments", { targetType, targetId, page, limit })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? data.docs
    : Array.isArray(data?.comments)
    ? data.comments
    : Array.isArray(data?.items)
    ? data.items
    : Array.isArray(data)
    ? data
    : [];
  const comments = flattenComments(list as unknown[]);
  const total = Number(data?.totalDocs ?? data?.total ?? comments.length);
  return { comments, total };
}

export async function listAllComments(targetType: string, targetId: string) {
  const all: MediaComment[] = [];
  const seen = new Set<string>();
  let page = 1;
  let total = 0;
  const limit = 80;
  while (page <= 40) {
    const batch = await listComments(targetType, targetId, page, limit);
    total = Number(batch.total || total);
    let added = 0;
    for (const comment of batch.comments) {
      if (seen.has(comment.id)) continue;
      seen.add(comment.id);
      all.push(comment);
      added += 1;
    }
    if (!added || all.length >= total || batch.comments.length < limit) break;
    page += 1;
  }
  return { comments: all, total: Math.max(total, all.length) };
}

function flattenComments(list: unknown[]): MediaComment[] {
  const out: MediaComment[] = [];
  const walk = (item: unknown, forcedParent?: string) => {
    const parsed = normalizeComment(item);
    if (!parsed) return;
    const next = forcedParent && !parsed.parentId ? { ...parsed, parentId: forcedParent } : parsed;
    out.push(next);
    const raw = item && typeof item === "object" ? (item as Record<string, unknown>) : null;
    const nested = raw?.replies ?? raw?.children ?? (raw?.comment && typeof raw.comment === "object"
      ? (raw.comment as Record<string, unknown>).replies
      : undefined);
    if (Array.isArray(nested)) {
      for (const child of nested) walk(child, next.id);
    }
  };
  for (const item of list) walk(item);
  return out;
}

export async function createComment(
  targetType: string,
  targetId: string,
  content: string,
  parentId?: string
) {
  const body: Record<string, unknown> = { targetType, targetId, content };
  if (parentId) body.parentId = parentId;
  const res = await api.post<Record<string, unknown>>("/api/x-live/comments", body);
  const parsed = normalizeComment(res);
  if (parsed) return parsed;
  const data = (res && typeof res === "object" && "data" in res ? res.data : res) as unknown;
  return normalizeComment(data);
}

export async function getLikeSummary(targetType: string, targetId: string) {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/likes", { targetType, targetId })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return {
    count: Number(data?.count ?? data?.likeCount ?? data?.total ?? data?.likes ?? 0),
    likedByMe: Boolean(data?.likedByMe ?? data?.liked ?? data?.isLiked),
  };
}

const commentCountCache = new Map<string, number>();

export function countVisibleComments(comments: MediaComment[]): number {
  return comments.filter((c) => !isReactionComment(c.content)).length;
}

export function rememberCommentCount(targetType: string, targetId: string, count: number) {
  commentCountCache.set(`${targetType}:${targetId}`, count);
}

export function rememberedCommentCount(targetType: string, targetId: string): number | undefined {
  return commentCountCache.get(`${targetType}:${targetId}`);
}

export async function getCommentCount(targetType: string, targetId: string) {
  const full = await listAllComments(targetType, targetId);
  const count = countVisibleComments(full.comments);
  rememberCommentCount(targetType, targetId, count);
  return count;
}

export async function deleteComment(commentId: string) {
  return api.delete(`/api/x-live/comments/${commentId}`);
}

export async function likeMedia(targetType: string, targetId: string) {
  return api.post("/api/x-live/likes", { targetType, targetId });
}

export async function unlikeMedia(targetType: string, targetId: string) {
  return api.delete("/api/x-live/likes", { targetType, targetId });
}
