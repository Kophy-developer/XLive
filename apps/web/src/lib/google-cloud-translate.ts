import { createSign } from "crypto";
import { normalizeLiveLang, type LiveLang } from "./live-languages";

type ServiceAccount = {
  client_email?: string;
  private_key?: string;
  token_uri?: string;
  project_id?: string;
};

let cachedToken: { value: string; exp: number } | null = null;

function readServiceAccount(): ServiceAccount | null {
  const raw =
    process.env.GOOGLE_TTS_CREDENTIALS ||
    process.env.GOOGLE_CLOUD_TTS_CREDENTIALS ||
    process.env.GOOGLE_TRANSLATE_CREDENTIALS ||
    process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON ||
    "";
  if (!raw.trim()) return null;
  try {
    const parsed = JSON.parse(raw) as ServiceAccount;
    if (!parsed.client_email || !parsed.private_key) return null;
    return parsed;
  } catch {
    return null;
  }
}

function base64url(input: Buffer | string): string {
  const buf = Buffer.isBuffer(input) ? input : Buffer.from(input);
  return buf
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

async function getAccessToken(sa: ServiceAccount): Promise<string | null> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp > now + 60) return cachedToken.value;

  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/cloud-platform",
      aud: sa.token_uri || "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })
  );
  const unsigned = `${header}.${claim}`;
  const signer = createSign("RSA-SHA256");
  signer.update(unsigned);
  signer.end();
  const signature = base64url(signer.sign(sa.private_key as string));
  const jwt = `${unsigned}.${signature}`;

  const res = await fetch(sa.token_uri || "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) return null;
  const data = (await res.json()) as { access_token?: string; expires_in?: number };
  if (!data.access_token) return null;
  cachedToken = {
    value: data.access_token,
    exp: now + (Number(data.expires_in) || 3600),
  };
  return data.access_token;
}

export async function googleCloudTranslate(
  text: string,
  source: string,
  target: LiveLang
): Promise<{ text: string; source?: string; provider: string } | null> {
  const sa = readServiceAccount();
  if (!sa) return null;
  const token = await getAccessToken(sa);
  if (!token) return null;

  const body: Record<string, unknown> = {
    q: text,
    target,
    format: "text",
  };
  if (source && source !== "auto") body.source = source;

  const res = await fetch("https://translation.googleapis.com/language/translate/v2", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) return null;
  const data = (await res.json()) as {
    data?: {
      translations?: Array<{ translatedText?: string; detectedSourceLanguage?: string }>;
    };
  };
  const row = data?.data?.translations?.[0];
  const translated = String(row?.translatedText || "").trim();
  if (!translated) return null;
  return {
    text: translated,
    source: normalizeLiveLang(row?.detectedSourceLanguage) || (source === "auto" ? undefined : source),
    provider: "google",
  };
}
