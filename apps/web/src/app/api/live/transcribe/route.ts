import { NextRequest, NextResponse } from "next/server";
import { normalizeLiveLang } from "@/lib/live-languages";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 60;

export async function POST(req: NextRequest) {
  const key = process.env.GROQ_API_KEY;
  if (!key) {
    return NextResponse.json(
      { error: "groq_not_configured", text: "" },
      { status: 503 }
    );
  }

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return NextResponse.json({ error: "invalid_form" }, { status: 400 });
  }

  const file = form.get("file") || form.get("audio");
  if (!(file instanceof Blob) || file.size < 1) {
    return NextResponse.json({ error: "audio_required" }, { status: 400 });
  }
  if (file.size > 24 * 1024 * 1024) {
    return NextResponse.json({ error: "audio_too_large" }, { status: 413 });
  }

  const languageHint = normalizeLiveLang(String(form.get("language") || form.get("lang") || ""));
  const filename =
    (typeof (file as File).name === "string" && (file as File).name) || "audio.webm";

  const upstream = new FormData();
  upstream.append("file", file, filename);
  upstream.append("model", "whisper-large-v3-turbo");
  upstream.append("response_format", "json");
  if (languageHint) upstream.append("language", languageHint);

  try {
    const res = await fetch("https://api.groq.com/openai/v1/audio/transcriptions", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}` },
      body: upstream,
    });
    const raw = await res.text();
    if (!res.ok) {
      return NextResponse.json(
        { error: `groq_${res.status}`, text: "", detail: raw.slice(0, 300) },
        { status: 502 }
      );
    }
    let text = "";
    try {
      const json = JSON.parse(raw) as { text?: string };
      text = String(json.text || "").trim();
    } catch {
      text = raw.trim();
    }
    return NextResponse.json({
      text,
      language: languageHint || undefined,
      provider: "groq",
    });
  } catch {
    return NextResponse.json({ error: "groq_unreachable", text: "" }, { status: 502 });
  }
}
