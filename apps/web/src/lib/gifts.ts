import { getGiftCatalog } from "@/lib/api/misc";
import { getUserProfile } from "@/lib/api/feed";
import { api } from "@/lib/api/client";

export type GiftRow = {
  id: string;
  giftId?: string;
  giftName: string;
  senderId?: string;
  senderName: string;
  quantity: number;
  iconUrl?: string;
  amountPaid?: number;
  createdAt?: string;
};

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" ? (value as Record<string, unknown>) : null;
}

function listFromPayload(raw: unknown): Record<string, unknown>[] {
  const root = asRecord(raw) || {};
  const data = asRecord(root.data) || root;
  if (Array.isArray(data.docs)) return data.docs as Record<string, unknown>[];
  if (Array.isArray(data.gifts)) return data.gifts as Record<string, unknown>[];
  if (Array.isArray(data.items)) return data.items as Record<string, unknown>[];
  if (Array.isArray(data)) return data as Record<string, unknown>[];
  return [];
}

export function parseGiftRows(raw: unknown): GiftRow[] {
  return listFromPayload(raw)
    .map((g, i) => {
      const sender = asRecord(g.sender) || asRecord(g.user) || asRecord(g.from);
      const gift = asRecord(g.gift);
      const giftId = String(g.giftId ?? gift?.id ?? gift?._id ?? "").trim() || undefined;
      const senderId = String(g.senderId ?? sender?.id ?? sender?._id ?? "").trim() || undefined;
      return {
        id: String(g.id ?? g._id ?? `${giftId || "gift"}_${i}`),
        giftId,
        giftName: String(gift?.name ?? gift?.title ?? g.giftName ?? g.name ?? "").trim() || "Gift",
        senderId,
        senderName: String(
          sender?.displayName ?? sender?.username ?? sender?.name ?? g.senderName ?? ""
        ).trim() || "Viewer",
        quantity: Number(g.quantity ?? g.count ?? 1) || 1,
        iconUrl: gift?.iconUrl || gift?.icon || g.iconUrl
          ? String(gift?.iconUrl ?? gift?.icon ?? g.iconUrl)
          : undefined,
        amountPaid: Number(g.amountPaid ?? g.amountCredited ?? g.points ?? g.value ?? 0) || undefined,
        createdAt: String(g.createdAt ?? g.timestamp ?? "") || undefined,
      };
    })
    .filter((g) => g.id);
}

async function resolveUserName(userId: string, cache: Map<string, string>): Promise<string> {
  if (cache.has(userId)) return cache.get(userId)!;
  try {
    const res = await api.get<Record<string, unknown>>(`/api/x-live/users/${userId}`);
    const data = (res && typeof res === "object" && "data" in res && res.data
      ? res.data
      : res) as Record<string, unknown>;
    const name = String(data.displayName ?? data.username ?? "").trim();
    if (name) {
      cache.set(userId, name);
      return name;
    }
  } catch {
  }
  try {
    const profile = await getUserProfile(userId);
    const name = String(profile.displayName ?? profile.username ?? "").trim();
    if (name) {
      cache.set(userId, name);
      return name;
    }
  } catch {
  }
  cache.set(userId, "Viewer");
  return "Viewer";
}

export async function enrichGiftRows(rows: GiftRow[]): Promise<GiftRow[]> {
  if (!rows.length) return [];
  const catalog = await getGiftCatalog().catch(() => []);
  const byGiftId = new Map(catalog.map((g) => [g.id, g]));
  const userCache = new Map<string, string>();

  return Promise.all(
    rows.map(async (row) => {
      const catalogGift = row.giftId ? byGiftId.get(row.giftId) : undefined;
      const giftName =
        catalogGift?.name ||
        (row.giftName && row.giftName !== "Gift" ? row.giftName : "") ||
        "Gift";
      const iconUrl = catalogGift?.iconUrl || row.iconUrl;
      let senderName = row.senderName;
      if ((!senderName || senderName === "Viewer") && row.senderId) {
        senderName = await resolveUserName(row.senderId, userCache);
      }
      return {
        ...row,
        giftName,
        iconUrl,
        senderName: senderName || "Viewer",
      };
    })
  );
}

export function parseGiftSocketEvent(raw: unknown): {
  streamId?: string;
  senderName: string;
  giftName: string;
  quantity: number;
  senderId?: string;
  giftId?: string;
} {
  const root = asRecord(raw) || {};
  const data = asRecord(root.data) || asRecord(root.payload) || root;
  const sender = asRecord(data.sender) || asRecord(data.user) || asRecord(data.from);
  const gift = asRecord(data.gift);
  return {
    streamId: String(data.streamId ?? root.streamId ?? "").trim() || undefined,
    senderName: String(
      sender?.displayName ??
        sender?.username ??
        sender?.name ??
        data.senderName ??
        data.username ??
        ""
    ).trim() || "Viewer",
    giftName: String(gift?.name ?? gift?.title ?? data.giftName ?? data.name ?? "").trim() || "Gift",
    quantity: Number(data.quantity ?? data.count ?? 1) || 1,
    senderId: String(data.senderId ?? sender?.id ?? sender?._id ?? "").trim() || undefined,
    giftId: String(data.giftId ?? gift?.id ?? gift?._id ?? "").trim() || undefined,
  };
}

export async function resolveGiftSocketEvent(raw: unknown): Promise<{
  streamId?: string;
  senderName: string;
  giftName: string;
  quantity: number;
}> {
  const parsed = parseGiftSocketEvent(raw);
  const [enriched] = await enrichGiftRows([
    {
      id: `socket_${parsed.giftId || "gift"}_${parsed.senderId || "sender"}`,
      giftId: parsed.giftId,
      giftName: parsed.giftName,
      senderId: parsed.senderId,
      senderName: parsed.senderName,
      quantity: parsed.quantity,
    },
  ]);
  return {
    streamId: parsed.streamId,
    senderName: enriched?.senderName || parsed.senderName,
    giftName: enriched?.giftName || parsed.giftName,
    quantity: parsed.quantity,
  };
}
