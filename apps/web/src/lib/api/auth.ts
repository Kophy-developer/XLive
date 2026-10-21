import { authApi, api, withQuery } from "./client";
import { session } from "../session";
import type { XLiveUser } from "../types";
import { normalizePublicUser } from "./feed";

export type AuthLoginResult = {
  userId: string;
  identifier: string;
  needsVerification: boolean;
  emailVerified?: boolean;
  phoneVerified?: boolean;
};

export type BridgeTokenResult = {
  token: string;
  userId: string;
  user?: XLiveUser;
};

export async function checkAvailability(payload: {
  email?: string;
  username?: string;
  phone?: string;
}) {
  return authApi.post<{ available: boolean }>("/auth/check", payload);
}

export async function createAccount(payload: Record<string, string>) {
  return authApi.post<{ userId: string }>("/auth/create", payload);
}

export async function requestVerification(payload: { identifier: string; type: "email" | "phone" }) {
  return authApi.post<unknown>("/auth/verify-request", payload);
}

export async function verifyCode(payload: { identifier: string; code: string }) {
  return authApi.post<unknown>("/auth/verify-code", payload);
}

export async function login(identifier: string, password: string) {
  return authApi.post<AuthLoginResult>("/auth/login", { identifier, password });
}

export async function requestPasswordReset(identifier: string) {
  const trimmed = identifier.trim();
  let email = trimmed;
  if (!trimmed.includes("@")) {
    const resolved = await resolveUsernameEmail(trimmed);
    if (resolved) email = resolved;
  }
  return authApi.post<unknown>("/password/reset-request", { email, identifier: email });
}

export async function resetPassword(payload: { identifier: string; code: string; password: string }) {
  return authApi.post<unknown>("/password/reset", payload);
}

export async function resolveUsernameEmail(username: string): Promise<string | undefined> {
  const query = username.trim();
  if (!query) return undefined;
  try {
    const res = await api.get<Record<string, unknown> | Record<string, unknown>[]>(
      withQuery("/api/x-live/users/search", { q: query, limit: 5 }),
      false
    );
    const list: Record<string, unknown>[] = Array.isArray(res)
      ? (res as Record<string, unknown>[])
      : Array.isArray((res as Record<string, unknown>)?.data)
      ? ((res as Record<string, unknown>).data as Record<string, unknown>[])
      : Array.isArray((res as Record<string, unknown>)?.users)
      ? ((res as Record<string, unknown>).users as Record<string, unknown>[])
      : [];
    const normalized = query.toLowerCase();
    const match = list.find(
      (u) => typeof u?.username === "string" && u.username.toLowerCase() === normalized
    ) ?? list[0];
    return typeof match?.email === "string" ? match.email : undefined;
  } catch {
    return undefined;
  }
}

export async function bridgeToken(payload: Record<string, string>): Promise<BridgeTokenResult> {
  const res = await api.post<Record<string, unknown>>("/api/x-live/auth/token", payload, false);
  const data = (res && typeof res === "object" && "data" in res && res.data && typeof res.data === "object"
    ? res.data
    : res) as Record<string, unknown>;
  const token = typeof data?.token === "string" ? data.token : "";
  if (!token) {
    throw new Error(typeof res?.message === "string" ? res.message : "Bridge token missing");
  }
  const user = data?.user as XLiveUser | undefined;
  const userId = (user?.id ?? data?.userId ?? session.getUserId() ?? "") as string;
  return {
    token,
    userId,
    user,
  };
}

export async function completeAuth(loginResult: AuthLoginResult & { username?: string }) {
  let bridgePayload: Record<string, string>;

  if (loginResult.username) {
    bridgePayload = { username: loginResult.username };
  } else if (loginResult.identifier?.includes("@")) {
    bridgePayload = { email: loginResult.identifier };
  } else if (loginResult.identifier?.startsWith("+") || /^\d{7,}$/.test(loginResult.identifier || "")) {
    bridgePayload = { phone: loginResult.identifier };
  } else if (loginResult.userId) {
    bridgePayload = { id: loginResult.userId };
  } else {
    bridgePayload = { identifier: loginResult.identifier };
  }

  const bridge = await bridgeToken(bridgePayload);
  session.setJwt(bridge.token);
  session.setUserId(bridge.userId || loginResult.userId);
  session.setIdentifier(loginResult.identifier);
  return bridge;
}

export async function signIn(identifier: string, password: string) {
  const trimmed = identifier.trim();
  let loginIdentifier = trimmed;
  let resolvedEmail: string | undefined;
  let resolvedUsername: string | undefined;

  const isEmail = trimmed.includes("@");
  const isPhone = !isEmail && /^\+?\d{7,}$/.test(trimmed);

  if (!isEmail && !isPhone) {
    resolvedUsername = trimmed;
    resolvedEmail = await resolveUsernameEmail(trimmed);
    if (resolvedEmail) {
      loginIdentifier = resolvedEmail;
    }
  } else if (isEmail) {
    resolvedEmail = trimmed;
  }

  let loginResult: AuthLoginResult;
  try {
    loginResult = await login(loginIdentifier, password);
  } catch (err) {
    if (!isEmail && !isPhone && loginIdentifier !== trimmed) {
      try {
        loginResult = await login(trimmed, password);
      } catch {
        throw err;
      }
    } else {
      throw err;
    }
  }

  if (loginResult.needsVerification) {
    const err = new Error("Verification required") as Error & { needsVerification: boolean; identifier: string };
    err.needsVerification = true;
    err.identifier = loginResult.identifier || loginIdentifier;
    throw err;
  }

  return completeAuth({
    ...loginResult,
    identifier: resolvedEmail ?? loginResult.identifier ?? loginIdentifier,
    username: resolvedUsername,
  });
}

export async function signOut() {
  session.clear();
}

export async function getMe(): Promise<XLiveUser> {
  const res = await api.get<Record<string, unknown>>("/api/x-live/users/me");
  return normalizePublicUser(res);
}

export async function updateMe(data: Partial<XLiveUser>): Promise<XLiveUser> {
  const res = await api.patch<Record<string, unknown>>("/api/x-live/users/me", data);
  return normalizePublicUser(res);
}

export async function uploadAvatar(file: File) {
  const form = new FormData();
  form.append("file", file);
  const res = await api.upload<Record<string, unknown>>("/api/x-live/users/me/avatar", form);
  const data = (res && typeof res === "object" && "data" in res && res.data ? res.data : res) as Record<string, unknown>;
  return {
    avatarUrl: typeof data?.avatarUrl === "string" ? data.avatarUrl : "",
    user: data as unknown as XLiveUser,
  };
}
