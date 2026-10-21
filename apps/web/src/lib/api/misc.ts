import { ApiError, api, withQuery } from "./client";
import { session } from "../session";
import type { FeedItem, WalletInfo, GiftCatalogItem, NotificationItem } from "../types";
import { mediaTargetType } from "./social";

export async function getWallet(): Promise<WalletInfo> {
  const res = await api.get<Record<string, unknown>>("/api/x-live/wallet");
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return {
    balance: typeof data?.balance === "number" ? data.balance : Number(data?.balance ?? 0),
    currency: typeof data?.currency === "string" ? data.currency : "NGN",
  };
}

export async function getTransactions(page = 1) {
  const res = await api.get<Record<string, unknown>>(withQuery("/api/x-live/wallet/transactions", { page }));
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? data.docs
    : Array.isArray(data?.transactions)
    ? data.transactions
    : Array.isArray(data)
    ? data
    : [];
  return { transactions: list as Record<string, unknown>[] };
}

export type FundInitiatePayload = {
  amount: number;
  provider?: "paystack" | "paypal" | string;
  flow?: "redirect" | "sdk";
  coins?: number;
  packageId?: string;
};

export type FundInitiateResult = {
  paymentId: string;
  provider: string;
  flow: string;
  amountUsd: number;
  chargeAmount?: number;
  chargeCurrency?: string;
  authorizationUrl?: string;
  reference?: string;
};

export async function initiateFund(payload: number | FundInitiatePayload): Promise<FundInitiateResult> {
  const body = typeof payload === "number"
    ? { amount: payload, provider: "paystack", flow: "redirect", coins: payload * 100 }
    : {
        amount: payload.amount,
        provider: payload.provider || "paystack",
        flow: payload.flow || "redirect",
        ...(payload.coins ? { coins: payload.coins } : {}),
        ...(payload.packageId ? { packageId: payload.packageId } : {}),
      };

  const res = await api.post<Record<string, unknown>>("/api/x-live/wallet/fund/initiate", body);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;

  const clientPayload = (data.clientPayload as Record<string, unknown> | undefined);
  const authUrl = String(
    data.authorizationUrl ||
    data.approveUrl ||
    clientPayload?.authorizationUrl ||
    clientPayload?.approveUrl ||
    ""
  );

  return {
    paymentId: String(data.paymentId || data._id || ""),
    provider: String(data.provider || body.provider),
    flow: String(data.flow || body.flow),
    amountUsd: Number(data.amountUsd || body.amount),
    chargeAmount: typeof data.chargeAmount === "number" ? data.chargeAmount : undefined,
    chargeCurrency: typeof data.chargeCurrency === "string" ? data.chargeCurrency : undefined,
    authorizationUrl: authUrl || undefined,
    reference: typeof data.reference === "string" ? data.reference : undefined,
  };
}

export async function getPaymentStatus(paymentId: string) {
  const res = await api.get<Record<string, unknown>>(`/api/x-live/wallet/fund/payments/${paymentId}`);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return data;
}

export async function verifyFund(payload: { paymentId: string; reference?: string; orderId?: string }) {
  const res = await api.post<Record<string, unknown>>("/api/x-live/wallet/fund/verify", payload);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  return data;
}

export async function getGiftCatalog(): Promise<GiftCatalogItem[]> {
  const res = await api.get<Record<string, unknown> | GiftCatalogItem[]>("/api/x-live/gifts/catalog", false);
  const data = (res && typeof res === "object" && "data" in res && res.data !== undefined ? res.data : res) as
    | Record<string, unknown>
    | GiftCatalogItem[];
  const list = Array.isArray(data)
    ? data
    : Array.isArray((data as Record<string, unknown>)?.gifts)
    ? ((data as Record<string, unknown>).gifts as Record<string, unknown>[])
    : Array.isArray((data as Record<string, unknown>)?.items)
    ? ((data as Record<string, unknown>).items as Record<string, unknown>[])
    : Array.isArray((data as Record<string, unknown>)?.docs)
    ? ((data as Record<string, unknown>).docs as Record<string, unknown>[])
    : [];
  return (list as Record<string, unknown>[])
    .map((g) => ({
      id: String(g.id ?? g._id ?? g.giftId ?? ""),
      name: String(g.name ?? g.title ?? "Gift"),
      iconUrl: (g.iconUrl ?? g.icon ?? g.imageUrl) as string | undefined,
      price: Number(g.price ?? g.cost ?? g.coinPrice ?? 0) || 0,
    }))
    .filter((g) => g.id);
}

export async function sendGift(payload: { streamId: string; giftId: string; quantity: number }) {
  return api.post("/api/x-live/gifts/send", payload);
}

export async function getClipMarketplace(page = 1) {
  return api.get<{ listings: unknown[] }>(
    withQuery("/api/x-live/clips/marketplace/resale", { page })
  );
}

export async function getCreatorEarnings() {
  return api.get("/api/x-live/settings/creator/earnings");
}

export async function getCreatorAnalytics() {
  return api.get("/api/x-live/settings/creator/analytics");
}

export async function getCreatorSettings() {
  return api.get("/api/x-live/settings/creator");
}

export async function getMyClips() {
  return api.get("/api/x-live/clips/mine/created");
}

export async function getClipEarnings() {
  return api.get("/api/x-live/clips/mine/earnings");
}

export async function getSettings() {
  return api.get("/api/x-live/settings");
}

export async function updateSettings(data: Record<string, unknown>) {
  return api.patch("/api/x-live/settings", data);
}

export async function getBlocks() {
  return api.get("/api/x-live/settings/blocks");
}

export async function blockUser(userId: string) {
  return api.post("/api/x-live/settings/blocks", { userId });
}

export async function unblockUser(userId: string) {
  return api.delete(`/api/x-live/settings/blocks/${userId}`);
}

export async function getNotifications(page = 1, limit = 30) {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/notifications", { page, limit })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs)
    ? (data.docs as NotificationItem[])
    : Array.isArray(data?.notifications)
    ? (data.notifications as NotificationItem[])
    : Array.isArray(data)
    ? (data as NotificationItem[])
    : [];
  const unreadCount = typeof data?.unreadCount === "number" ? data.unreadCount : 0;
  return { notifications: list, unreadCount };
}

export async function markNotificationRead(id: string) {
  return api.post(`/api/x-live/notifications/${id}/read`);
}

export async function markAllNotificationsRead() {
  return api.post("/api/x-live/notifications/read-all");
}

export async function readVideoDurationSeconds(file: File): Promise<number> {
  const url = URL.createObjectURL(file);
  try {
    return await new Promise<number>((resolve, reject) => {
      const video = document.createElement("video");
      video.preload = "auto";
      video.muted = true;
      video.playsInline = true;
      let settled = false;
      const finish = (value: number) => {
        if (settled) return;
        if (!Number.isFinite(value) || value <= 0) return;
        settled = true;
        video.onloadedmetadata = null;
        video.ontimeupdate = null;
        video.onerror = null;
        video.removeAttribute("src");
        video.load();
        resolve(Math.max(1, Math.round(value)));
      };
      const fail = () => {
        if (settled) return;
        settled = true;
        video.onloadedmetadata = null;
        video.ontimeupdate = null;
        video.onerror = null;
        video.removeAttribute("src");
        video.load();
        reject(new Error("Could not read video length"));
      };
      video.onerror = fail;
      video.onloadedmetadata = () => {
        if (Number.isFinite(video.duration) && video.duration > 0) {
          finish(video.duration);
          return;
        }
        video.ontimeupdate = () => {
          if (Number.isFinite(video.duration) && video.duration > 0) {
            finish(video.duration);
            return;
          }
          if (Number.isFinite(video.currentTime) && video.currentTime > 0) {
            finish(video.currentTime);
          }
        };
        video.currentTime = 1e10;
      };
      video.src = url;
      window.setTimeout(fail, 10000);
    });
  } finally {
    URL.revokeObjectURL(url);
  }
}

const POST_VISIBILITY = new Set(["everyone", "followers", "subscribers"]);
const POST_CATEGORY = new Set([
  "music",
  "comedy",
  "education",
  "gaming",
  "lifestyle",
  "sports",
  "news",
  "other",
]);

function uploadFilenameForBrowserFile(file: File, isVideo: boolean) {
  let name = (file.name || "").trim() || (isVideo ? "upload.mp4" : "upload.jpg");
  if (isVideo && !/\.(mp4|m4v|mov|webm|mkv|avi)$/i.test(name)) {
    name = name.includes(".") ? name.replace(/\.[^.]+$/, ".mp4") : `${name}.mp4`;
  } else if (!isVideo && !/\.(png|jpe?g|webp|gif|heic|heif)$/i.test(name)) {
    name = name.includes(".") ? name.replace(/\.[^.]+$/, ".jpg") : `${name}.jpg`;
  }
  return name;
}

export async function uploadVideo(
  file: File,
  metadata?: {
    caption?: string;
    visibility?: string;
    category?: string;
    unlockPrice?: string | number;
    soundCopyrightChecked?: boolean | string;
    type?: string;
    duration?: number;
  }
) {
  const visibilityRaw = (metadata?.visibility || "everyone").trim().toLowerCase();
  const categoryRaw = (metadata?.category || "music").trim().toLowerCase();
  const visibility = POST_VISIBILITY.has(visibilityRaw) ? visibilityRaw : "everyone";
  const category = POST_CATEGORY.has(categoryRaw) ? categoryRaw : "other";
  const isVideo = file.type.startsWith("video/") || /\.(mp4|m4v|mov|webm|mkv)$/i.test(file.name);
  const filename = uploadFilenameForBrowserFile(file, isVideo);
  const uploadFile =
    filename === file.name
      ? file
      : new File([file], filename, { type: file.type || (isVideo ? "video/mp4" : "image/jpeg") });

  const form = new FormData();
  form.append("file", uploadFile);
  form.append("type", metadata?.type || "post");
  form.append("visibility", visibility);
  form.append("category", category);
  form.append("mediaType", isVideo ? "video" : "image");
  form.append("soundCopyrightChecked", String(metadata?.soundCopyrightChecked ?? true));
  if (metadata?.caption) form.append("caption", metadata.caption);
  if (metadata?.unlockPrice && Number(metadata.unlockPrice) > 0) {
    form.append("unlockPrice", String(metadata.unlockPrice));
  }
  if (isVideo) {
    const duration = metadata?.duration && metadata.duration > 0
      ? Math.max(1, Math.round(metadata.duration))
      : await readVideoDurationSeconds(file);
    form.append("duration", String(duration));
  }
  return api.upload<Record<string, unknown>>("/api/x-live/videos/upload", form);
}

export async function uploadCollectibleClip(
  file: File,
  metadata?: {
    name?: string;
    title?: string;
    caption?: string;
    description?: string;
    price?: string | number;
    maxSupply?: string | number;
  }
) {
  const form = new FormData();
  form.append("file", file);
  const name = metadata?.name || metadata?.title || "Collectible Clip";
  form.append("name", name);
  form.append("title", name);
  form.append("price", String(metadata?.price ?? 5));
  form.append("maxSupply", String(metadata?.maxSupply ?? 10));
  const desc = metadata?.description || metadata?.caption || "";
  if (desc) {
    form.append("description", desc);
    form.append("caption", desc);
  }
  return api.upload<Record<string, unknown>>("/api/x-live/clips/collectible", form);
}

export async function createClip(payload: Record<string, unknown>) {
  return api.post("/api/x-live/clips", payload);
}

export async function getVideo(videoId: string): Promise<Record<string, unknown>> {
  const res = await api.get<Record<string, unknown>>(`/api/x-live/videos/${videoId}`, session.isAuthenticated());
  return (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown>;
}

export async function getClip(clipId: string): Promise<Record<string, unknown>> {
  const res = await api.get<Record<string, unknown>>(`/api/x-live/clips/${clipId}`, session.isAuthenticated());
  return (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown>;
}

export async function deleteVideo(videoId: string) {
  return api.delete(`/api/x-live/videos/${videoId}`);
}

export async function deleteClip(clipId: string) {
  return api.delete(`/api/x-live/clips/${clipId}`);
}

export async function deleteOwnedMedia(item: { id: string; type?: string }) {
  if (item.type === "clip") return deleteClip(item.id);
  return deleteVideo(item.id);
}

const insightsCache = new Map<string, number | null>();

export async function getOwnerInsightsViews(item: Pick<FeedItem, "id" | "type">): Promise<number | null> {
  const key = `${item.type}:${item.id}`;
  if (insightsCache.has(key)) return insightsCache.get(key) ?? null;
  const tryKind = async (kind: "video" | "clip") => {
    const res = await api.get<Record<string, unknown>>(`/api/x-live/insights/${kind}/${item.id}`);
    const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
      ? res.data
      : res) as Record<string, unknown>;
    const views = data?.views ?? data?.viewCount;
    if (typeof views === "number" && Number.isFinite(views)) return views;
    if (typeof views === "string" && views.trim() && Number.isFinite(Number(views))) return Number(views);
    return null;
  };
  const order: Array<"video" | "clip"> =
    mediaTargetType(item.type) === "clip" ? ["clip", "video"] : ["video", "clip"];
  for (const kind of order) {
    try {
      const views = await tryKind(kind);
      insightsCache.set(key, views);
      return views;
    } catch (err) {
      if (err instanceof ApiError && (err.status === 404 || err.status === 403)) continue;
      insightsCache.set(key, null);
      return null;
    }
  }
  insightsCache.set(key, null);
  return null;
}
