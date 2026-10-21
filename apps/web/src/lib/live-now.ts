import { getLiveFeed } from "./api/feed";

let liveCreatorIds = new Set<string>();
let fetchedAt = 0;

export function isCreatorLiveNow(creatorId?: string | null): boolean {
  const id = creatorId?.trim();
  if (!id) return false;
  return liveCreatorIds.has(id);
}

export async function refreshLiveNowCreators(force = false): Promise<void> {
  if (!force && fetchedAt && Date.now() - fetchedAt < 45_000) return;
  try {
    const { items } = await getLiveFeed(1);
    const next = new Set<string>();
    for (const item of items) {
      const id = item.creatorId?.trim();
      if (id) next.add(id);
    }
    liveCreatorIds = next;
    fetchedAt = Date.now();
  } catch {
    liveCreatorIds = new Set();
  }
}
