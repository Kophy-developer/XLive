import { api, withQuery } from "./client";

export interface CreatorEarningsData {
  balance: number;
  currency: string;
  totalWithdrawn: number;
  totalEarnedInRange: number;
  breakdown: {
    streamGifts: number;
    privateStreams: number;
    streams: number;
    clips: number;
    posts: number;
    subscriptions: number;
  };
  range?: {
    preset: string;
    from: string;
    to: string;
  };
}

export interface CreatorAnalyticsData {
  range?: {
    preset: string;
    from: string;
    to: string;
  };
  metrics: {
    profileViews: number;
    postViews: number;
    clipViews: number;
    shares: number;
    likes: number;
    comments: number;
    liveStreams: number;
    streamJoins: number;
    watchTimeSeconds: number;
    giftRevenue: number;
  };
}

export interface CreatorSettingsData {
  userId: string;
  privateStreamPricePerMinute: number;
  allowViewerTalkBack: boolean;
}

export async function getCreatorEarnings(range: "today" | "week" | "month" = "today"): Promise<CreatorEarningsData> {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/settings/creator/earnings", { range })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as unknown as CreatorEarningsData;
  return data;
}

export async function getCreatorAnalytics(range: "today" | "week" | "month" = "today"): Promise<CreatorAnalyticsData> {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/settings/creator/analytics", { range })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as unknown as CreatorAnalyticsData;
  return data;
}

export async function getCreatorSettings(): Promise<CreatorSettingsData> {
  const res = await api.get<Record<string, unknown>>("/api/x-live/settings/creator");
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as unknown as CreatorSettingsData;
  return data;
}

export async function updateCreatorSettings(payload: Partial<CreatorSettingsData>): Promise<CreatorSettingsData> {
  const res = await api.patch<Record<string, unknown>>("/api/x-live/settings/creator", payload);
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as unknown as CreatorSettingsData;
  return data;
}

export async function getArchivedClips(page = 1, limit = 20) {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/settings/creator/clips/archived", { page, limit })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs) ? data.docs : Array.isArray(data?.clips) ? data.clips : [];
  return {
    docs: list as Record<string, unknown>[],
    totalDocs: typeof data?.totalDocs === "number" ? data.totalDocs : list.length,
  };
}

export async function changeUserPassword(payload: { currentPassword?: string; newPassword: string }) {
  return api.patch("/api/x-live/users/me/password", payload);
}

export async function setUserPasscode(passcode: string) {
  return api.put("/api/x-live/users/me/passcode", { passcode });
}

export async function removeUserPasscode() {
  return api.delete("/api/x-live/users/me/passcode");
}

export async function getUserFollowers(userId: string, page = 1, limit = 20) {
  const res = await api.get<Record<string, unknown>>(
    withQuery(`/api/x-live/follow/${userId}/followers`, { page, limit })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs) ? data.docs : Array.isArray(data) ? data : [];
  return {
    docs: list as Record<string, unknown>[],
    totalDocs: typeof data?.totalDocs === "number" ? data.totalDocs : list.length,
  };
}

export async function getUserFollowing(userId: string, page = 1, limit = 20) {
  const res = await api.get<Record<string, unknown>>(
    withQuery(`/api/x-live/follow/${userId}/following`, { page, limit })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs) ? data.docs : Array.isArray(data) ? data : [];
  return {
    docs: list as Record<string, unknown>[],
    totalDocs: typeof data?.totalDocs === "number" ? data.totalDocs : list.length,
  };
}

export async function getUserGifts(page = 1, limit = 20) {
  const res = await api.get<Record<string, unknown>>(
    withQuery("/api/x-live/gifts/me/received", { page, limit })
  );
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown>;
  const list = Array.isArray(data?.docs) ? data.docs : Array.isArray(data) ? data : [];
  return {
    docs: list as Record<string, unknown>[],
    totalDocs: typeof data?.totalDocs === "number" ? data.totalDocs : list.length,
  };
}
