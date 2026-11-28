import { NextRequest, NextResponse } from "next/server";
import { googleCloudStandardTts } from "@/lib/google-cloud-tts";
import { normalizeLiveLang, type LiveLang } from "@/lib/live-languages";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Body = {
  text?: string;
  lang?: string;
};

const AZURE_VOICE: Record<LiveLang, string> = {
  en: "en-US-JennyNeural",
  es: "es-ES-ElviraNeural",
  fr: "fr-FR-DeniseNeural",
  zh: "zh-CN-XiaoxiaoNeural",
};

async function azureTts(text: string, lang: LiveLang): Promise<Buffer | null> {
  const key =
    process.env.AZURE_SPEECH_KEY ||
    process.env.AZURE_TTS_KEY ||
    process.env.AZURE_TRANSLATOR_KEY ||
    process.env.AZURE_TRANSLATOR_API_KEY;
  const region =
    process.env.AZURE_SPEECH_REGION ||
    process.env.AZURE_TTS_REGION ||
    process.env.AZURE_TRANSLATOR_REGION ||
    "";
  if (!key || !region) return null;

  const voice = AZURE_VOICE[lang] || AZURE_VOICE.en;
  const locale = voice.split("-").slice(0, 2).join("-");
  const ssml = `<speak version='1.0' xml:lang='${locale}'><voice xml:lang='${locale}' name='${voice}'>${text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")}</voice></speak>`;

  const res = await fetch(`https://${region}.tts.speech.microsoft.com/cognitiveservices/v1`, {
    method: "POST",
    headers: {
      "Ocp-Apim-Subscription-Key": key,
      "Content-Type": "application/ssml+xml",
      "X-Microsoft-OutputFormat": "audio-16khz-128kbitrate-mono-mp3",
      "User-Agent": "xlive",
    },
    body: ssml,
  });
  if (!res.ok) return null;
  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.length < 200) return null;
  return buf;
}

async function unofficialGoogleTts(text: string, lang: LiveLang): Promise<Buffer | null> {
  const tl = lang === "zh" ? "zh-CN" : lang;
  const url = `https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&q=${encodeURIComponent(text)}&tl=${encodeURIComponent(tl)}`;
  const res = await fetch(url, {
    method: "GET",
    headers: { "User-Agent": "Mozilla/5.0" },
  });
  if (!res.ok) return null;
  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.length < 200) return null;
  return buf;
}

function audioResponse(buf: Buffer, provider: string) {
  return new NextResponse(new Uint8Array(buf), {
    status: 200,
    headers: {
      "Content-Type": "audio/mpeg",
      "Cache-Control": "no-store",
      "X-TTS-Provider": provider,
    },
  });
}

export async function POST(req: NextRequest) {
  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }

  const text = String(body.text || "").trim().slice(0, 180);
  if (!text) {
    return NextResponse.json({ error: "text_required" }, { status: 400 });
  }

  const lang = (normalizeLiveLang(body.lang) || "en") as LiveLang;

  try {
    const cloud = await googleCloudStandardTts(text, lang);
    if (cloud) return audioResponse(cloud, "google-cloud-standard");

    const azure = await azureTts(text, lang);
    if (azure) return audioResponse(azure, "azure");

    const fallback = await unofficialGoogleTts(text, lang);
    if (fallback) return audioResponse(fallback, "google-unofficial");
  } catch {
  }

  return NextResponse.json({ error: "tts_failed" }, { status: 502 });
}
