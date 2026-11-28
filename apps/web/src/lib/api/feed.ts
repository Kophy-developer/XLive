import { api, withQuery } from "./client";
import type { FeedItem, XLiveUser } from "../types";
import { parsePresence, type PresenceInfo } from "../presence";
import { isRemovedFeedRecord, pickMediaUrl, pickThumbnailUrl, publicHandle, looksLikeVideoUrl } from "../utils";
import { keepVisibleFeedItems } from "../media-gone";
import { coalesceFeedAlbums } from "../feed-album";
import { session } from "../session";
import { getCommentCount, mediaTargetType, rememberedCommentCount } from "./social";

function pickMetric(...values: unknown[]): number {
  for (const value of values) {
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (typeof value === "string" && value.trim() && Number.isFinite(Number(value))) return Number(value);
    if (Array.isArray(value)) return value.length;
    if (value && typeof value === "object") {
      const obj = value as Record<string, unknown>;
      const nested = obj.count ?? obj.total ?? obj.totalDocs ?? obj.totalCount;
      if (typeof nested === "number" && Number.isFinite(nested)) return nested;
    }
  }
  return 0;
}

function pickHandle(source?: Record<string, unknown> | null): string {
  if (!source) return "";
  return publicHandle({
    username: source.username as string | undefined,
    handle: source.handle as string | undefined,
    userName: source.userName as string | undefined,
    email: source.email as string | undefined,
  });
}

export function normalizePublicUser(raw: unknown): XLiveUser {
  const root = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const d = (
    root.data && typeof root.data === "object"
      ? root.data
      : root.user && typeof root.user === "object"
      ? root.user
      : root.profile && typeof root.profile === "object"
      ? root.profile
      : root
  ) as Record<string, unknown>;
  const username = pickHandle(d) || pickHandle(root);
  const languageRaw = d.language ?? d.lang ?? root.language ?? root.lang;
  const language =
    typeof languageRaw === "string" && languageRaw.trim()
      ? languageRaw.trim().toLowerCase()
      : undefined;
  const settingsRaw =
    (d.settings && typeof d.settings === "object" ? d.settings : null) ||
    (root.settings && typeof root.settings === "object" ? root.settings : null);
  return {
    id: String(d.id ?? d._id ?? root.id ?? root._id ?? ""),
    username: username || "",
    displayName: (d.displayName ?? d.name ?? d.firstName) as string | undefined,
    avatarUrl: (d.avatarUrl ?? d.avatar ?? d.profileImage) as string | undefined,
    bio: d.bio as string | undefined,
    gender: (d.gender ?? root.gender) as string | undefined,
    language,
    isCreator: Boolean(d.isCreator ?? d.creator ?? root.isCreator) || String(d.role ?? root.role ?? "") === "creator",
    followerCount: pickMetric(d.followerCount, d.followersCount, d.followers),
    followingCount: pickMetric(d.followingCount, d.following),
    isFollowing: d.isFollowing === true || root.isFollowing === true,
    settings: settingsRaw
      ? (settingsRaw as XLiveUser["settings"])
      : undefined,
  };
}

export function normalizeFeedItem(raw: Record<string, unknown>): FeedItem {
  const d = (raw?.data && typeof raw.data === "object" ? raw.data : {}) as Record<string, unknown>;
  const stream = (raw?.stream && typeof raw.stream === "object" ? raw.stream : {}) as Record<string, unknown>;

  const id = String(raw?.id ?? raw?._id ?? d?._id ?? d?.id ?? stream?._id ?? stream?.id ?? "");
  const streamId = (raw?.streamId ?? d?.streamId ?? stream?._id ?? stream?.id ?? (raw?.type === "live" ? id : undefined)) as string | undefined;

  const typeStr = String(raw?.feedType ?? raw?.type ?? d?.type ?? d?.kind ?? raw?.kind ?? (streamId ? "live" : "post")).toLowerCase();
  let type: "video" | "clip" | "live" | "post" = "post";
  if (typeStr.includes("live") || typeStr.includes("stream") || streamId) {
    type = "live";
  } else if (typeStr.includes("clip")) {
    type = "clip";
  } else if (typeStr.includes("video") || typeStr.includes("reel")) {
    type = "video";
  }

  const mediaUrl = pickMediaUrl(raw, d);
  const thumbnailUrl = pickThumbnailUrl(raw, d, stream) || (mediaUrl && !/\.(mp4|m4v|mov|webm|mkv|m3u8)(\?|$)/i.test(mediaUrl) ? mediaUrl : undefined);

  const mediaTypeRaw = String(d?.mediaType ?? raw?.mediaType ?? "").toLowerCase();
  let mediaType: "video" | "image" | undefined;
  if (looksLikeVideoUrl(mediaUrl)) mediaType = "video";
  else if (mediaTypeRaw.includes("image") || mediaTypeRaw.includes("photo")) mediaType = "image";
  else if (mediaTypeRaw.includes("video") || mediaTypeRaw.includes("reel")) mediaType = "video";
  else if (mediaUrl && /\.(jpg|jpeg|png|webp|gif|heic|heif|avif)(\?|$)/i.test(mediaUrl)) mediaType = "image";
  else if (type === "video" || type === "clip") mediaType = "video";

  const caption = (
    d?.caption ??
    raw?.caption ??
    d?.title ??
    raw?.title ??
    d?.name ??
    raw?.name ??
    d?.description ??
    raw?.description ??
    stream?.title ??
    ""
  ) as string;

  const title = (
    d?.title ??
    raw?.title ??
    d?.name ??
    raw?.name ??
    caption ??
    ""
  ) as string;

  const creatorObj = (d?.user ?? raw?.user ?? d?.creator ?? raw?.creator ?? d?.author ?? raw?.author ?? stream?.host ?? stream?.creator ?? d?.owner ?? raw?.owner) as Record<string, unknown> | undefined;
  const creatorUsername =
    pickHandle(creatorObj) ||
    publicHandle(d?.username as string) ||
    publicHandle(raw?.username as string) ||
    publicHandle(d?.handle as string) ||
    publicHandle(raw?.handle as string) ||
    publicHandle(d?.creatorUsername as string) ||
    publicHandle(raw?.creatorUsername as string);
  const creatorAvatarUrl = (creatorObj?.avatarUrl ?? d?.creatorAvatarUrl ?? raw?.creatorAvatarUrl ?? creatorObj?.avatar ?? creatorObj?.profileImage) as string | undefined;
  const creatorId = String(
    creatorObj?.id ?? creatorObj?._id ?? d?.userId ?? raw?.userId ?? d?.creatorId ?? raw?.creatorId ?? d?.ownerId ?? raw?.ownerId ?? stream?.hostId ?? ""
  ) || undefined;

  const creator: XLiveUser | undefined =
    creatorId || creatorUsername
      ? {
          id: creatorId ?? "",
          username: creatorUsername,
          displayName: (creatorObj?.displayName ?? d?.creatorDisplayName ?? raw?.creatorDisplayName) as string | undefined,
          avatarUrl: creatorAvatarUrl,
        }
      : undefined;

  const likeCount = pickMetric(d?.likeCount, raw?.likeCount, d?.likes, raw?.likes, d?.totalLikes);
  const commentCount = pickMetric(
    d?.commentCount,
    raw?.commentCount,
    d?.totalComments,
    raw?.totalComments,
    d?.commentsCount,
    raw?.commentsCount
  );
  const viewCount = pickMetric(d?.viewCount, raw?.viewCount, d?.views, raw?.views);
  const price = typeof d?.price === "number" ? d.price : typeof raw?.price === "number" ? raw.price : undefined;
  const isLive = Boolean(raw?.isLive ?? d?.isLive ?? stream?.isLive ?? type === "live");
  const createdAt = (d?.createdAt ?? raw?.createdAt ?? stream?.createdAt) as string | undefined;

  const access = (raw?.access ?? d?.access) as Record<string, unknown> | undefined;
  const accessAllowed = access ? access.allowed !== false : true;
  const needsPurchase = Boolean(access?.needsPurchase);

  return {
    id,
    type,
    mediaType,
    title: title || caption || "Untitled",
    caption: caption || title,
    thumbnailUrl,
    previewUrl: (d?.previewUrl ?? raw?.previewUrl) as string | undefined,
    mediaUrl,
    streamUrl: (d?.streamUrl ?? raw?.streamUrl) as string | undefined,
    creator,
    creatorId,
    creatorName: creatorUsername,
    creatorAvatarUrl,
    isFollowing: Boolean(creatorObj?.isFollowing ?? creatorObj?.following ?? d?.isFollowing ?? raw?.isFollowing),
    likedByMe: Boolean(d?.likedByMe ?? raw?.likedByMe ?? d?.isLiked ?? raw?.isLiked ?? d?.liked),
    likeCount,
    commentCount,
    viewCount,
    price,
    isLive,
    streamId,
    createdAt,
    accessAllowed,
    needsPurchase,
    isOwner: Boolean(d?.isOwner ?? raw?.isOwner ?? d?.ownedByMe ?? raw?.ownedByMe),
  };
}

const profileCache = new Map<string, XLiveUser>();

async function mapPool<T>(items: T[], limit: number, fn: (item: T) => Promise<void>) {
  let cursor = 0;
  async function worker() {
    while (cursor < items.length) {
      const index = cursor++;
      await fn(items[index]);
    }
  }
  const size = Math.min(limit, items.length);
  if (!size) return;
  await Promise.all(Array.from({ length: size }, () => worker()));
}

export async function enrichFeedItems(items: FeedItem[]): Promise<FeedItem[]> {
  if (!items.length) return items;
  const missingProfiles = Array.from(
    new Set(
      items
        .filter((item) => item.creatorId && !publicHandle(item.creator) && !publicHandle(item.creatorName))
        .map((item) => item.creatorId as string)
    )
  ).filter((id) => !profileCache.has(id));

  await mapPool(missingProfiles, 4, async (id) => {
    try {
      const profile = await getUserProfile(id);
      if (profile?.id) profileCache.set(id, profile);
    } catch {
    }
  });

  const missingCounts = items.filter((item) => {
    if (item.type === "live" || item.isLive) return false;
    return rememberedCommentCount(mediaTargetType(item.type), item.id) === undefined;
  });

  await mapPool(missingCounts, 5, async (item) => {
    try {
      await getCommentCount(mediaTargetType(item.type), item.id);
    } catch {
    }
  });

  return coalesceFeedAlbums(keepVisibleFeedItems(items)).map((item) => {
    const profile = item.creatorId ? profileCache.get(item.creatorId) : undefined;
    const username = publicHandle(item.creator) || publicHandle(item.creatorName) || publicHandle(profile);
    const comments = rememberedCommentCount(mediaTargetType(item.type), item.id);
    return {
      ...item,
      creator: {
        id: item.creatorId || item.creator?.id || profile?.id || "",
        username: username || item.creator?.username || "",
        displayName: item.creator?.displayName || profile?.displayName,
        avatarUrl: item.creatorAvatarUrl || item.creator?.avatarUrl || profile?.avatarUrl,
      },
      creatorName: username,
      creatorAvatarUrl: item.creatorAvatarUrl || item.creator?.avatarUrl || profile?.avatarUrl,
      commentCount: comments ?? item.commentCount ?? 0,
    };
  });
}

function unwrapFeedEntry(item: Record<string, unknown>): Record<string, unknown> {
  const nested =
    (item.video && typeof item.video === "object" ? item.video : null) ||
    (item.clip && typeof item.clip === "object" ? item.clip : null) ||
    (item.post && typeof item.post === "object" ? item.post : null) ||
    (item.content && typeof item.content === "object" ? item.content : null) ||
    (item.item && typeof item.item === "object" ? item.item : null);
  if (!nested) return item;
  return { ...item, ...(nested as Record<string, unknown>) };
}

function feedItemsFromResponse(res: Record<string, unknown> | null | undefined) {
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const items = Array.isArray(data?.items)
    ? data.items
    : Array.isArray(data?.docs)
    ? data.docs
    : Array.isArray(data?.videos)
    ? data.videos
    : Array.isArray(data?.posts)
    ? data.posts
    : Array.isArray(data?.feed)
    ? data.feed
    : Array.isArray(data?.results)
    ? data.results
    : Array.isArray(data)
    ? data
    : [];
  const normalized = items
    .map((i) => unwrapFeedEntry(i as Record<string, unknown>))
    .filter((i) => !isRemovedFeedRecord(i))
    .map((i) => normalizeFeedItem(i))
    .filter((i) => i.id);
  const hasMore = typeof data?.hasMore === "boolean"
    ? data.hasMore
    : data?.totalPages && data?.page
    ? Number(data.page) < Number(data.totalPages)
    : normalized.length >= 10;
  return { items: coalesceFeedAlbums(keepVisibleFeedItems(normalized)), hasMore };
}

function prependFresh(base: FeedItem[], extra: FeedItem[]) {
  const seen = new Set(base.map((item) => item.id).filter(Boolean));
  const fresh = extra
    .filter((item) => item.id && !seen.has(item.id))
    .sort((a, b) => (Date.parse(b.createdAt || "") || 0) - (Date.parse(a.createdAt || "") || 0));
  return [...fresh, ...base];
}

async function fetchLatestVideos(limit = 24): Promise<FeedItem[]> {
  try {
    const res = await api.get<Record<string, unknown>>(
      withQuery("/api/x-live/videos", { page: 1, limit }),
      session.isAuthenticated()
    );
    return feedItemsFromResponse(res).items;
  } catch {
    return [];
  }
}

async function fetchOwnContent(): Promise<FeedItem[]> {
  const userId = session.getUserId();
  if (!userId) return [];
  try {
    const res = await api.get<Record<string, unknown>>(
      withQuery(`/api/x-live/users/${userId}/content`, { page: 1 }),
      true
    );
    return feedItemsFromResponse(res).items;
  } catch {
    return [];
  }
}

export async function getForYouFeed(page = 1) {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/feed/for-you", { page }),
    session.isAuthenticated()
  );
  const parsed = feedItemsFromResponse(res);
  let items = parsed.items;
  if (page === 1) {
    const [latest, mine] = await Promise.all([fetchLatestVideos(24), fetchOwnContent()]);
    items = prependFresh(items, [...latest, ...mine]);
  }
  return {
    items: await enrichFeedItems(items),
    hasMore: parsed.hasMore,
  };
}

export async function getFollowingFeed(page = 1) {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/feed/following", { page, limit: 30 })
  );
  const parsed = feedItemsFromResponse(res);
  if (parsed.items.length || page > 1) {
    return {
      items: await enrichFeedItems(parsed.items),
      hasMore: parsed.hasMore,
    };
  }
  const fallback = await followingFeedFromPeople();
  return { items: await enrichFeedItems(fallback), hasMore: false };
}

async function followingFeedFromPeople(): Promise<FeedItem[]> {
  const userId = session.getUserId();
  if (!userId) return [];
  try {
    const res = await api.get<Record<string, unknown>>(
      withQuery(`/api/x-live/follow/${userId}/following`, { page: 1, limit: 40 })
    );
    const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown>;
    const list = Array.isArray(data?.docs)
      ? data.docs
      : Array.isArray(data?.following)
      ? data.following
      : Array.isArray(data)
      ? data
      : [];
    const ids = Array.from(
      new Set(
        (list as Record<string, unknown>[])
          .map((row) => followTargetId(row))
          .filter((id) => id && id !== userId)
      )
    ).slice(0, 20);
    const batches = await Promise.all(
      ids.map(async (id) => {
        try {
          const content = await api.get<Record<string, unknown>>(
            withQuery(`/api/x-live/users/${id}/content`, { page: 1 }),
            false
          );
          return feedItemsFromResponse(content).items;
        } catch {
          return [] as FeedItem[];
        }
      })
    );
    const merged = batches.flat();
    const seen = new Set<string>();
    return merged
      .filter((item) => {
        if (!item.id || seen.has(item.id)) return false;
        seen.add(item.id);
        return true;
      })
      .sort((a, b) => (Date.parse(b.createdAt || "") || 0) - (Date.parse(a.createdAt || "") || 0));
  } catch {
    return [];
  }
}

function followTargetId(row: Record<string, unknown>) {
  const nested = [row.user, row.followed, row.following, row.followee, row.target, row.profile].find(
    (value) => value && typeof value === "object"
  ) as Record<string, unknown> | undefined;
  return String(
    nested?.id ??
      nested?._id ??
      row.userId ??
      row.followingId ??
      row.followedId ??
      row.followeeId ??
      row.id ??
      row._id ??
      ""
  );
}

export async function getClipsFeed(page = 1) {
  const res = await api.get<Record<string, unknown>>(withQuery("/api/x-live/feed/clips", { page }), false);
  const parsed = feedItemsFromResponse(res);
  return {
    items: await enrichFeedItems(parsed.items),
    hasMore: parsed.hasMore,
  };
}

export async function getLiveFeed(page = 1) {
  try {
    const res = await api.get<Record<string, unknown>>(
      withQuery("/api/x-live/feed/live", { page, limit: 30 }),
      false
    );
    const parsed = feedItemsFromResponse(res);
    const liveItems = parsed.items.filter((item) => item.type === "live" || item.isLive);
    if (liveItems.length) {
      return {
        items: await enrichFeedItems(liveItems),
        hasMore: parsed.hasMore,
      };
    }
  } catch {
    return liveFeedFromStreams(page);
  }
  return liveFeedFromStreams(page);
}

async function liveFeedFromStreams(page: number) {
  if (page > 1) return { items: [] as FeedItem[], hasMore: false };
  const { getLiveStreams } = await import("./streams");
  const { streams } = await getLiveStreams();
  const items = streams
    .filter((stream) => stream.id)
    .map((stream) => ({
      id: stream.id,
      type: "live" as const,
      title: stream.title || "Live stream",
      caption: stream.caption || stream.title,
      thumbnailUrl: stream.thumbnailUrl,
      creator: stream.host,
      creatorId: stream.hostId,
      creatorName: stream.host?.username || stream.host?.displayName,
      creatorAvatarUrl: stream.host?.avatarUrl,
      isLive: true,
      streamId: stream.id,
      createdAt: stream.startedAt || stream.createdAt,
    }));
  return { items: await enrichFeedItems(items), hasMore: false };
}

export type ExploreSearchData = {
  query: string;
  users: XLiveUser[];
  videos: FeedItem[];
  clips: FeedItem[];
  streams: FeedItem[];
  hashtags: { tag: string; count?: number }[];
  groups: { id: string; name: string; avatarUrl?: string; memberCount?: number }[];
};

export async function searchExplore(q: string, limit = 24): Promise<ExploreSearchData> {
  const trimmed = q.trim();
  const normalizedQuery = trimmed.replace(/^#/, "");
  if (!normalizedQuery) {
    return { query: "", users: [], videos: [], clips: [], streams: [], hashtags: [], groups: [] };
  }
  try {
    const [exploreRes, usersRes] = await Promise.allSettled([
      api.get<Record<string, unknown>>(
        withQuery("/api/x-live/explore/search", { q: normalizedQuery, limit }),
        false
      ),
      api.get<Record<string, unknown> | Record<string, unknown>[]>(
        withQuery("/api/x-live/users/search", { q: normalizedQuery, limit: 10 }),
        false
      ),
    ]);

    const exploreData = (exploreRes.status === "fulfilled" && exploreRes.value && typeof exploreRes.value === "object" && "data" in exploreRes.value && exploreRes.value.data
      ? exploreRes.value.data
      : exploreRes.status === "fulfilled"
      ? exploreRes.value
      : {}) as Record<string, unknown>;

    const directUsersRaw = (usersRes.status === "fulfilled" && usersRes.value && typeof usersRes.value === "object" && "data" in usersRes.value && usersRes.value.data
      ? usersRes.value.data
      : usersRes.status === "fulfilled"
      ? usersRes.value
      : []) as Record<string, unknown> | Record<string, unknown>[];

    const directUsers = (Array.isArray(directUsersRaw)
      ? directUsersRaw
      : Array.isArray((directUsersRaw as Record<string, unknown>)?.users)
      ? ((directUsersRaw as Record<string, unknown>).users as Record<string, unknown>[])
      : []) as Record<string, unknown>[];

    const exploreUsers = Array.isArray(exploreData?.users) ? (exploreData.users as Record<string, unknown>[]) : [];

    const userMap = new Map<string, XLiveUser>();
    for (const u of [...directUsers, ...exploreUsers]) {
      const normalized = normalizePublicUser(u);
      if (normalized.id && (publicHandle(normalized) || normalized.displayName) && !userMap.has(normalized.id)) {
        userMap.set(normalized.id, normalized);
      }
    }

    const videosList = Array.isArray(exploreData?.videos)
      ? keepVisibleFeedItems(
          (exploreData.videos as Record<string, unknown>[])
            .filter((v) => !isRemovedFeedRecord(v))
            .map((v) => normalizeFeedItem(v))
        )
      : [];
    const clipsList = Array.isArray(exploreData?.clips)
      ? keepVisibleFeedItems(
          (exploreData.clips as Record<string, unknown>[])
            .filter((c) => !isRemovedFeedRecord(c))
            .map((c) => normalizeFeedItem({ ...c, type: "clip" }))
        )
      : [];
    const streamsList = Array.isArray(exploreData?.streams)
      ? (exploreData.streams as Record<string, unknown>[]).map((s) => normalizeFeedItem({ ...s, type: "live", isLive: true }))
      : [];
    const hashtagsList = Array.isArray(exploreData?.hashtags)
      ? (exploreData.hashtags as Record<string, unknown>[]).map((h) => ({
          tag: String(h.tag ?? h.name ?? "").replace(/^#/, ""),
          count: typeof h.count === "number" ? h.count : typeof h.uses === "number" ? h.uses : typeof h.usageCount === "number" ? h.usageCount : 0,
        }))
      : [];
    const groupsList = Array.isArray(exploreData?.groups)
      ? (exploreData.groups as Record<string, unknown>[]).map((g) => ({
          id: String(g.id ?? g._id ?? ""),
          name: String(g.name ?? "Group"),
          avatarUrl: (g.avatarUrl ?? g.iconUrl ?? g.image) as string | undefined,
          memberCount: typeof g.membersCount === "number" ? g.membersCount : typeof g.memberCount === "number" ? g.memberCount : undefined,
        }))
      : [];

    return {
      query: trimmed,
      users: Array.from(userMap.values()),
      videos: videosList,
      clips: clipsList,
      streams: streamsList,
      hashtags: hashtagsList,
      groups: groupsList,
    };
  } catch {
    return { query: trimmed, users: [], videos: [], clips: [], streams: [], hashtags: [], groups: [] };
  }
}

export async function getOnlineUsers(limit = 24) {
  const me = session.getUserId();
  const collected = new Map<string, XLiveUser>();

  const addUser = (user: XLiveUser | undefined | null) => {
    if (!user?.id || user.id === me) return;
    const handle = publicHandle(user);
    const existing = collected.get(user.id);
    collected.set(user.id, {
      ...existing,
      ...user,
      username: handle || publicHandle(existing) || "",
      displayName: user.displayName || existing?.displayName,
      avatarUrl: user.avatarUrl || existing?.avatarUrl,
    });
  };

  try {
    const res = await api.get<Record<string, unknown> | Record<string, unknown>[]>(
      withQuery("/api/x-live/users/online", { page: 1, limit }),
      true
    );
    const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as
      | Record<string, unknown>
      | Record<string, unknown>[];
    const list = Array.isArray(data)
      ? data
      : Array.isArray((data as Record<string, unknown>)?.docs)
      ? ((data as Record<string, unknown>).docs as Record<string, unknown>[])
      : Array.isArray((data as Record<string, unknown>)?.users)
      ? ((data as Record<string, unknown>).users as Record<string, unknown>[])
      : Array.isArray((data as Record<string, unknown>)?.items)
      ? ((data as Record<string, unknown>).items as Record<string, unknown>[])
      : Array.isArray((data as Record<string, unknown>)?.creators)
      ? ((data as Record<string, unknown>).creators as Record<string, unknown>[])
      : [];
    for (const row of list) {
      const nested =
        row.user && typeof row.user === "object"
          ? (row.user as Record<string, unknown>)
          : row.profile && typeof row.profile === "object"
          ? (row.profile as Record<string, unknown>)
          : row;
      addUser(normalizePublicUser({ ...row, ...nested }));
    }
  } catch {}

  if (Array.from(collected.values()).filter((user) => publicHandle(user) || user.displayName).length < 8) {
    try {
      const feed = await getForYouFeed(1);
      for (const item of feed.items) {
        if (item.creator) addUser(item.creator);
        else if (item.creatorId) {
          addUser(
            normalizePublicUser({
              id: item.creatorId,
              username: item.creatorName,
              displayName: item.creatorName,
              avatarUrl: item.creatorAvatarUrl,
            })
          );
        }
      }
    } catch {}
  }

  const missing = Array.from(collected.values())
    .filter((user) => !publicHandle(user))
    .slice(0, limit);
  await Promise.all(
    missing.map(async (user) => {
      try {
        addUser(await getUserProfile(user.id));
      } catch {
        return;
      }
    })
  );

  return {
    users: Array.from(collected.values())
      .filter((user) => publicHandle(user) || Boolean(user.displayName?.trim()))
      .slice(0, limit),
  };
}

export async function searchUsers(q: string) {
  const trimmed = q.trim();
  if (!trimmed) return { users: [] };
  const res = await api.get<Record<string, unknown> | Record<string, unknown>[]>(withQuery("/api/x-live/users/search", { q: trimmed }));
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown> | Record<string, unknown>[];
  const list = Array.isArray(data)
    ? data
    : Array.isArray((data as Record<string, unknown>)?.users)
    ? ((data as Record<string, unknown>).users as Record<string, unknown>[])
    : [];
  return {
    users: list
      .map((row) => normalizePublicUser(row))
      .filter((user) => user.id && (publicHandle(user) || user.displayName)),
  };
}

export async function searchHashtags(q: string) {
  const res = await api.get<Record<string, unknown> | Record<string, unknown>[]>(withQuery("/api/x-live/hashtags/search", { q }), false);
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown> | Record<string, unknown>[];
  const list = Array.isArray(data) ? data : Array.isArray((data as Record<string, unknown>)?.tags) ? (data as Record<string, unknown>).tags : [];
  return { tags: list as { tag: string; count: number }[] };
}

export async function getTrendingHashtags() {
  const res = await api.get<Record<string, unknown> | Record<string, unknown>[]>("/api/x-live/hashtags/trending", false);
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown> | Record<string, unknown>[];
  const list = Array.isArray(data) ? (data as Record<string, unknown>[]) : Array.isArray((data as Record<string, unknown>)?.tags) ? ((data as Record<string, unknown>).tags as Record<string, unknown>[]) : [];
  return {
    tags: list.map((t) => ({
      tag: String(t.tag ?? t.name ?? ""),
      count: typeof t.count === "number" ? t.count : typeof t.uses === "number" ? t.uses : typeof t.usageCount === "number" ? t.usageCount : 0,
    })),
  };
}

export async function getHashtagFeed(tag: string, page = 1) {
  const res = await api.get<Record<string, unknown>>(
    withQuery(`/api/x-live/hashtags/${encodeURIComponent(tag)}/feed`, { page }),
    false
  );
  const parsed = feedItemsFromResponse(res);
  return { items: await enrichFeedItems(parsed.items), hasMore: parsed.hasMore };
}

export async function getUserProfile(userId: string) {
  const res = await api.get<Record<string, unknown>>(`/api/x-live/users/${userId}/profile`);
  return normalizePublicUser(res);
}

export async function getUserPresence(userId: string): Promise<PresenceInfo> {
  try {
    const res = await api.get<unknown>(`/api/x-live/users/${userId}/presence`);
    return parsePresence(res);
  } catch {
    return { online: false, label: "Offline" };
  }
}

export async function getUserContent(userId: string, page = 1) {
  const res = await api.get<Record<string, unknown>>(
    withQuery(`/api/x-live/users/${userId}/content`, { page }),
    false
  );
  const parsed = feedItemsFromResponse(res);
  return { items: await enrichFeedItems(parsed.items), hasMore: parsed.hasMore };
}

export async function followUser(userId: string) {
  return api.post("/api/x-live/follow/follow", { userId, followingId: userId });
}

export async function unfollowUser(userId: string) {
  return api.post("/api/x-live/follow/unfollow", { userId });
}
