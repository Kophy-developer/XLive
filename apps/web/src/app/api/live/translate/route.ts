import { NextRequest, NextResponse } from "next/server";
import { googleCloudTranslate } from "@/lib/google-cloud-translate";
import { LIVE_LANGS, normalizeLiveLang, type LiveLang } from "@/lib/live-languages";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Body = {
  text?: string;
  source?: string;
  target?: string;
};

async function azureTranslate(text: string, source: string, target: LiveLang) {
  const key = process.env.AZURE_TRANSLATOR_KEY || process.env.AZURE_TRANSLATOR_API_KEY;
  const region = process.env.AZURE_TRANSLATOR_REGION || process.env.AZURE_SPEECH_REGION || "global";
  const endpoint =
    process.env.AZURE_TRANSLATOR_ENDPOINT || "https://api.cognitive.microsofttranslator.com";
  if (!key) return null;

  const params = new URLSearchParams({ "api-version": "3.0", to: target });
  if (source && source !== "auto") params.set("from", source);

  const res = await fetch(`${endpoint.replace(/\/$/, "")}/translate?${params}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Ocp-Apim-Subscription-Key": key,
      "Ocp-Apim-Subscription-Region": region,
    },
    body: JSON.stringify([{ Text: text }]),
  });
  if (!res.ok) return null;
  const data = (await res.json()) as Array<{
    detectedLanguage?: { language?: string };
    translations?: Array<{ text?: string; to?: string }>;
  }>;
  const row = data?.[0];
  const translated = row?.translations?.[0]?.text;
  if (!translated) return null;
  return {
    text: translated,
    source: normalizeLiveLang(row?.detectedLanguage?.language) || source || undefined,
    provider: "azure",
  };
}

async function myMemoryTranslate(text: string, source: string, target: LiveLang) {
  const from = source && source !== "auto" ? source : "autodetect";
  const langpair = `${from}|${target}`;
  const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=${encodeURIComponent(langpair)}`;
  const res = await fetch(url, { method: "GET" });
  if (!res.ok) return null;
  const data = (await res.json()) as {
    responseData?: { translatedText?: string };
    responseStatus?: number;
  };
  const translated = String(data?.responseData?.translatedText || "").trim();
  if (!translated || data.responseStatus !== 200) return null;
  if (/^\s*invalid|query length|my memory/i.test(translated)) return null;
  if (translated === text) return null;
  return {
    text: translated,
    source: source === "auto" ? undefined : source,
    provider: "mymemory",
  };
}

async function gtxTranslate(text: string, source: string, target: LiveLang) {
  const sl = source && source !== "auto" ? source : "auto";
  const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${encodeURIComponent(sl)}&tl=${encodeURIComponent(target)}&dt=t&q=${encodeURIComponent(text)}`;
  const res = await fetch(url, {
    method: "GET",
    headers: { "User-Agent": "Mozilla/5.0" },
  });
  if (!res.ok) return null;
  const data = (await res.json()) as unknown;
  if (!Array.isArray(data) || !Array.isArray(data[0])) return null;
  const translated = data[0]
    .map((row: unknown) => (Array.isArray(row) ? String(row[0] || "") : ""))
    .join("")
    .trim();
  if (!translated || translated === text) return null;
  return {
    text: translated,
    source: source === "auto" ? undefined : source,
    provider: "gtx",
  };
}

export async function POST(req: NextRequest) {
  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }

  const text = String(body.text || "").trim();
  if (!text) {
    return NextResponse.json({ error: "text_required" }, { status: 400 });
  }
  if (text.length > 2000) {
    return NextResponse.json({ error: "text_too_long" }, { status: 400 });
  }

  const target = normalizeLiveLang(body.target);
  if (!target || !(LIVE_LANGS as readonly string[]).includes(target)) {
    return NextResponse.json({ error: "unsupported_target" }, { status: 400 });
  }

  const sourceRaw = String(body.source || "auto").trim().toLowerCase();
  const source = sourceRaw === "auto" ? "auto" : normalizeLiveLang(sourceRaw) || "auto";

  if (source !== "auto" && source === target) {
    return NextResponse.json({
      text,
      translated: false,
      source,
      target,
      provider: "none",
    });
  }

  try {
    const google = await googleCloudTranslate(text, source, target);
    if (google?.text) {
      return NextResponse.json({
        text: google.text,
        translated: google.text.trim() !== text,
        source: google.source || (source === "auto" ? undefined : source),
        target,
        provider: google.provider,
      });
    }

    const azure = await azureTranslate(text, source, target);
    if (azure?.text) {
      return NextResponse.json({
        text: azure.text,
        translated: azure.text.trim() !== text,
        source: azure.source || (source === "auto" ? undefined : source),
        target,
        provider: azure.provider,
      });
    }

    const fallback = await myMemoryTranslate(text, source, target);
    if (fallback?.text) {
      return NextResponse.json({
        text: fallback.text,
        translated: fallback.text.trim() !== text,
        source: fallback.source,
        target,
        provider: fallback.provider,
      });
    }

    const gtx = await gtxTranslate(text, source, target);
    if (gtx?.text) {
      return NextResponse.json({
        text: gtx.text,
        translated: gtx.text.trim() !== text,
        source: gtx.source,
        target,
        provider: gtx.provider,
      });
    }
  } catch {
  }

  return NextResponse.json({
    text,
    translated: false,
    source: source === "auto" ? undefined : source,
    target,
    provider: "none",
  });
}
