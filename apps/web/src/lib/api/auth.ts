import { ApiError, authApi, api } from "./client";
import { session } from "../session";
import type { XLiveUser } from "../types";
import { normalizePublicUser } from "./feed";

/** Response envelope used by every /api/x-live endpoint (confirmed against the live server). */
type Envelope<T> = { message: string; status: boolean; statusCode: number; data: T; error: unknown };

/** Success `data` of POST /auth/verify-email and POST /auth/login: `{ token, user }`. */
type TokenData = { token: string; user: Record<string, unknown> };

/** Backend password rule (POST /auth/create, /auth/reset-password, /auth/change-password validation). */
export const PASSWORD_MIN_LENGTH = 8;

/** Says exactly what to fix when `password` breaks the backend rule, else null. */
export function passwordRuleError(password: string): string | null {
  const missing = PASSWORD_MIN_LENGTH - password.length;
  return missing > 0 ? `Password must be at least ${PASSWORD_MIN_LENGTH} characters. Add ${missing} more.` : null;
}

/**
 * Password text from a 400 validation error: `error.password` on /auth/create,
 * `error[""]` (e.g. "newPassword must be at least 8 characters") on reset/change.
 */
export function serverPasswordError(err: unknown): string | null {
  if (!(err instanceof ApiError)) return null;
  const fields = (err.body as { error?: Record<string, unknown> } | null)?.error;
  for (const key of ["password", ""]) {
    const value = fields?.[key];
    if (typeof value === "string" && value.includes("assword")) return value;
  }
  return null;
}

/** 403 body of POST /auth/login for an unverified account (any identifier). */
type EmailNotVerifiedBody = { error: { code: "EMAIL_NOT_VERIFIED"; email: string; verificationSent: boolean } };

/** Thrown when POST /auth/login answers 403: the account's email is not verified yet. */
export class EmailNotVerifiedError extends ApiError {
  /** The account's email, from the 403 body, so the code can be (re)sent there. */
  email: string;

  constructor(err: ApiError) {
    super(err.message, err.status, err.body);
    this.email = (err.body as EmailNotVerifiedBody).error.email;
  }
}

function startSession(res: Envelope<TokenData>, identifier: string): XLiveUser {
  const user = normalizePublicUser(res.data.user);
  session.setJwt(res.data.token);
  session.setUserId(user.id);
  session.setIdentifier(identifier);
  return user;
}

export function normalizeAuthPhone(raw: string, defaultCountryCode = "234"): string {
  const trimmed = raw.trim();
  if (!trimmed) return "";
  const digits = trimmed.replace(/\D/g, "");
  if (!digits) return "";
  if (trimmed.startsWith("+")) return `+${digits}`;
  if (digits.startsWith(defaultCountryCode)) return `+${digits}`;
  if (digits.startsWith("0") && digits.length >= 10) {
    return `+${defaultCountryCode}${digits.slice(1)}`;
  }
  if (digits.length >= 10) return `+${defaultCountryCode}${digits}`;
  return `+${digits}`;
}

/** POST /auth/check — whether an email or phone number is already registered. */
/** POST /auth/check: whether an email or phone number is already registered. */
export async function checkExists(variable: string): Promise<boolean> {
  const res = await authApi.post<Envelope<{ exists: boolean }>>("/auth/check", { variable: variable.trim() });
  return res.data.exists;
}

/** Throws a 409 ApiError when the email or phone is already registered. */
export async function checkAvailability(payload: { email: string; phone?: string }) {
  if (await checkExists(payload.email)) {
    throw new ApiError("This email is already registered. Sign in or reset your password instead.", 409);
  }
  if (payload.phone && (await checkExists(payload.phone))) {
    throw new ApiError("This phone number is already registered.", 409);
  }
}

/**
 * POST /auth/create: registers the account and emails a 6-digit code. No token is
 * issued until the email is verified. Duplicate usernames are rejected here, and the
 * server's message is surfaced through ApiError.
 */
export async function createAccount(payload: {
  firstName: string;
  lastName: string;
  username: string;
  email: string;
  phone: string;
  password: string;
}): Promise<void> {
  await authApi.post<Envelope<unknown>>("/auth/create", {
    first_name: payload.firstName.trim(),
    last_name: payload.lastName.trim(),
    username: payload.username.trim(),
    email: payload.email.trim(),
    phone: normalizeAuthPhone(payload.phone),
    password: payload.password,
  });
}

/** POST /auth/resend-verification: emails a fresh 6-digit code. */
export async function resendVerification(email: string) {
  await authApi.post<Envelope<unknown>>("/auth/resend-verification", { email: email.trim() });
}

/** POST /auth/verify-email: activates the account and starts the session with the returned JWT. */
export async function verifyEmail(email: string, code: string): Promise<XLiveUser> {
  const res = await authApi.post<Envelope<TokenData>>("/auth/verify-email", {
    email: email.trim(),
    code: code.trim(),
  });
  return startSession(res, email.trim());
}

/**
 * POST /auth/login with email, username or phone plus password, then starts the session.
 * Throws EmailNotVerifiedError on 403.
 */
export async function signIn(identifier: string, password: string): Promise<XLiveUser> {
  const id = identifier.trim();
  const body: Record<string, string> = { password };
  if (id.includes("@")) body.email = id;
  else if (/^\+?\d{7,}$/.test(id.replace(/[\s\-()]/g, ""))) body.phone = normalizeAuthPhone(id);
  else body.username = id;
  try {
    const res = await authApi.post<Envelope<TokenData>>("/auth/login", body);
    return startSession(res, id);
  } catch (err) {
    if (err instanceof ApiError && err.status === 403) throw new EmailNotVerifiedError(err);
    throw err;
  }
}

/** POST /auth/forgot-password: emails a 6-digit reset code. */
export async function requestPasswordReset(email: string) {
  await authApi.post<Envelope<{ sent: boolean; expiresInMinutes: number }>>("/auth/forgot-password", {
    email: email.trim(),
  });
}

/** POST /auth/reset-password with the 6-digit code from forgot-password. */
export async function resetPassword(payload: { email: string; code: string; newPassword: string }) {
  await authApi.post<Envelope<unknown>>("/auth/reset-password", {
    email: payload.email.trim(),
    code: payload.code.trim(),
    newPassword: payload.newPassword,
  });
}

/** POST /auth/change-password (Bearer) for the signed-in user. */
export async function changePassword(payload: { currentPassword: string; newPassword: string }) {
  await authApi.post<Envelope<unknown>>("/auth/change-password", payload, true);
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
