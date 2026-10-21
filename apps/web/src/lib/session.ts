const JWT_KEY = "xlive_jwt";
const USER_ID_KEY = "xlive_user_id";
const IDENTIFIER_KEY = "xlive_identifier";
const CREATOR_MODE_KEY = "xlive_creator_mode";

export const session = {
  getJwt(): string | null {
    if (typeof window === "undefined") return null;
    return localStorage.getItem(JWT_KEY);
  },
  setJwt(token: string) {
    localStorage.setItem(JWT_KEY, token);
  },
  getUserId(): string | null {
    if (typeof window === "undefined") return null;
    return localStorage.getItem(USER_ID_KEY);
  },
  setUserId(userId: string) {
    localStorage.setItem(USER_ID_KEY, userId);
  },
  getIdentifier(): string | null {
    if (typeof window === "undefined") return null;
    return localStorage.getItem(IDENTIFIER_KEY);
  },
  setIdentifier(identifier: string) {
    localStorage.setItem(IDENTIFIER_KEY, identifier);
  },
  getCreatorMode(): boolean {
    if (typeof window === "undefined") return false;
    return localStorage.getItem(CREATOR_MODE_KEY) === "1";
  },
  setCreatorMode(enabled: boolean) {
    if (typeof window === "undefined") return;
    if (enabled) localStorage.setItem(CREATOR_MODE_KEY, "1");
    else localStorage.removeItem(CREATOR_MODE_KEY);
  },
  clear() {
    localStorage.removeItem(JWT_KEY);
    localStorage.removeItem(USER_ID_KEY);
    localStorage.removeItem(IDENTIFIER_KEY);
  },
  isAuthenticated(): boolean {
    return Boolean(this.getJwt());
  },
};
