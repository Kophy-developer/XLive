export type PresenceInfo = {
  online: boolean;
  label: string;
};

const STALE_MS = 5 * 60 * 1000;
const ONLINE_WORDS = new Set(["online", "active_now", "activenow", "available"]);
const OFFLINE_WORDS = new Set(["offline", "away", "invisible", "idle", "unavailable"]);

function unwrap(raw: unknown): Record<string, unknown> {
  if (!raw || typeof raw !== "object") return {};
  const o = raw as Record<string, unknown>;
  if (o.data && typeof o.data === "object" && !Array.isArray(o.data)) {
    return unwrap(o.data);
  }
  if (o.presence && typeof o.presence === "object" && !Array.isArray(o.presence)) {
    return o.presence as Record<string, unknown>;
  }
  return o;
}

function boolFlag(value: unknown): boolean | undefined {
  if (value === true || value === 1 || value === "true" || value === "1") return true;
  if (value === false || value === 0 || value === "false" || value === "0") return false;
  return undefined;
}

function parseWhen(value: unknown): Date | null {
  if (value == null || value === "") return null;
  if (typeof value === "number" && Number.isFinite(value)) {
    const ms = value < 1e12 ? value * 1000 : value;
    const d = new Date(ms);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  const d = new Date(String(value));
  return Number.isNaN(d.getTime()) ? null : d;
}

function formatLastSeen(at: Date): string {
  const local = new Date(at.getTime());
  const now = new Date();
  const diff = now.getTime() - local.getTime();
  if (diff < 60_000) return "just now";
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (now.toDateString() === local.toDateString()) {
    return `today ${local.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })}`;
  }
  if (diff < 7 * 24 * 3_600_000) {
    return local.toLocaleDateString(undefined, { weekday: "short" });
  }
  return local.toLocaleDateString();
}

export function parsePresence(raw: unknown): PresenceInfo {
  const d = unwrap(raw);
  const lastSeen = parseWhen(
    d.lastSeen ?? d.lastSeenAt ?? d.last_seen ?? d.lastActive ?? d.lastActiveAt ?? d.lastOnlineAt
  );
  const onlineFlag = boolFlag(d.online) ?? boolFlag(d.isOnline) ?? boolFlag(d.is_online);
  const word = String(d.presence ?? d.activityStatus ?? d.onlineStatus ?? d.state ?? "")
    .toLowerCase()
    .trim();
  const statusWord = String(d.status ?? "").toLowerCase().trim();
  const wordOnline = ONLINE_WORDS.has(word) || statusWord === "online";
  const wordOffline = OFFLINE_WORDS.has(word) || statusWord === "offline" || statusWord === "away";

  let online = false;
  if (onlineFlag === false || wordOffline) online = false;
  else if (onlineFlag === true || wordOnline) online = true;

  if (lastSeen) {
    const age = Date.now() - lastSeen.getTime();
    if (age > STALE_MS) online = false;
  }

  if (online) return { online: true, label: "Active now" };
  if (lastSeen) return { online: false, label: `Last seen ${formatLastSeen(lastSeen)}` };
  return { online: false, label: "Offline" };
}
