import { createSign } from "crypto";
import type { LiveLang } from "./live-languages";

type ServiceAccount = {
  client_email?: string;
  private_key?: string;
  token_uri?: string;
};

const STANDARD_VOICE: Record<LiveLang, { languageCode: string; name: string }> = {
  en: { languageCode: "en-US", name: "en-US-Standard-C" },
  es: { languageCode: "es-ES", name: "es-ES-Standard-A" },
  fr: { languageCode: "fr-FR", name: "fr-FR-Standard-A" },
  zh: { languageCode: "zh-CN", name: "zh-CN-Standard-A" },
};

let cachedToken: { value: string; exp: number } | null = null;

function readServiceAccount(): ServiceAccount | null {
  const raw =
    process.env.GOOGLE_TTS_CREDENTIALS ||
    process.env.GOOGLE_CLOUD_TTS_CREDENTIALS ||
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

export async function googleCloudStandardTts(
  text: string,
  lang: LiveLang
): Promise<Buffer | null> {
  const sa = readServiceAccount();
  if (!sa) return null;
  const token = await getAccessToken(sa);
  if (!token) return null;

  const voice = STANDARD_VOICE[lang] || STANDARD_VOICE.en;
  const res = await fetch("https://texttospeech.googleapis.com/v1/text:synthesize", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      input: { text },
      voice: {
        languageCode: voice.languageCode,
        name: voice.name,
      },
      audioConfig: {
        audioEncoding: "MP3",
        speakingRate: 1.05,
      },
    }),
  });
  if (!res.ok) return null;
  const data = (await res.json()) as { audioContent?: string };
  if (!data.audioContent) return null;
  const buf = Buffer.from(data.audioContent, "base64");
  if (buf.length < 200) return null;
  return buf;
}

export function hasGoogleCloudTtsCredentials(): boolean {
  return Boolean(readServiceAccount());
}
