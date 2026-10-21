import { session } from "./session";
import type { XLiveUser } from "./types";

export function creatorToolsEnabled(user?: XLiveUser | null) {
  return Boolean(user?.isCreator) || session.getCreatorMode();
}

export function setCreatorMode(enabled: boolean) {
  session.setCreatorMode(enabled);
}
