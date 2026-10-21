import { emitSocket } from "./socket";

export type CaptionChunk = {
  text: string;
  isFinal: boolean;
  sourceLang?: string;
  segmentId: string;
  mode?: string;
  streamId?: string;
};

type SpeechRecognitionCtor = new () => {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  onresult: ((event: {
    resultIndex: number;
    results: ArrayLike<{ isFinal: boolean; 0: { transcript: string } }>;
  }) => void) | null;
  onerror: (() => void) | null;
  onend: (() => void) | null;
  start: () => void;
  stop: () => void;
};

export function normalizeCaptionPayload(input: unknown): CaptionChunk | null {
  const raw = (Array.isArray(input) ? input[0] : input) as Record<string, unknown> | null;
  if (!raw || typeof raw !== "object") return null;
  const doc = (
    raw.data && typeof raw.data === "object"
      ? raw.data
      : raw.payload && typeof raw.payload === "object"
      ? raw.payload
      : raw
  ) as Record<string, unknown>;
  const text = String(doc.text ?? doc.content ?? doc.transcript ?? "").trim();
  if (!text) return null;
  return {
    text,
    isFinal: doc.isFinal !== false && doc.final !== false,
    sourceLang: String(doc.sourceLang ?? doc.lang ?? doc.language ?? "") || undefined,
    segmentId: String(doc.segmentId ?? doc.sentence_id ?? doc.id ?? Date.now()),
    mode: String(doc.mode ?? "") || undefined,
    streamId: String(doc.streamId ?? raw.streamId ?? "") || undefined,
  };
}

export function captionTextForRole(chunk: CaptionChunk, isHost: boolean): string | null {
  const text = chunk.text.trim();
  if (!text) return null;
  if (isHost && chunk.mode === "translated") return null;
  return text;
}

export function emitTranscriptChunk(streamId: string, chunk: CaptionChunk) {
  const text = chunk.text.trim();
  if (!streamId || !text) return;
  emitSocket("stream_transcript_chunk", {
    streamId,
    segmentId: chunk.segmentId,
    text,
    sourceLang: chunk.sourceLang,
    isFinal: chunk.isFinal !== false,
    timestamp: Date.now(),
  });
}

function toBytes(data: unknown): Uint8Array | null {
  if (!data) return null;
  if (data instanceof Uint8Array) return data;
  if (data instanceof ArrayBuffer) return new Uint8Array(data);
  if (ArrayBuffer.isView(data)) {
    return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
  }
  if (typeof data === "string") return new TextEncoder().encode(data);
  return null;
}

export function parseAgoraCaptionPayload(data: unknown): CaptionChunk | null {
  const bytes = toBytes(data);
  try {
    const raw = typeof data === "string" ? data : new TextDecoder().decode(bytes || new Uint8Array());
    const trimmed = raw.trim();
    if (trimmed.startsWith("{")) {
      return normalizeCaptionPayload(JSON.parse(trimmed));
    }
    if (trimmed.length > 1 && trimmed.length < 500 && /^[\x20-\x7E\u00A0-\uFFFF]+$/.test(trimmed)) {
      return {
        text: trimmed,
        isFinal: true,
        segmentId: `stt_${Date.now()}`,
      };
    }
  } catch {
  }
  return null;
}

export function startHostSpeechCaptions(options: {
  lang?: string;
  onChunk: (chunk: CaptionChunk) => void;
}): () => void {
  const SpeechRecognition = (
    typeof window !== "undefined"
      ? (window as unknown as { SpeechRecognition?: SpeechRecognitionCtor; webkitSpeechRecognition?: SpeechRecognitionCtor })
          .SpeechRecognition ||
        (window as unknown as { webkitSpeechRecognition?: SpeechRecognitionCtor }).webkitSpeechRecognition
      : undefined
  ) as SpeechRecognitionCtor | undefined;
  if (!SpeechRecognition) return () => {};

  let active = true;
  const recognition = new SpeechRecognition();
  recognition.continuous = true;
  recognition.interimResults = true;
  const code = (options.lang || "en-US").toLowerCase();
  const map: Record<string, string> = { en: "en-US", es: "es-ES", fr: "fr-FR", de: "de-DE", pt: "pt-BR" };
  recognition.lang = map[code] || (code.includes("-") ? options.lang || "en-US" : "en-US");

  recognition.onresult = (event) => {
    let interim = "";
    let finalText = "";
    for (let i = event.resultIndex; i < event.results.length; i++) {
      const piece = event.results[i][0]?.transcript || "";
      if (event.results[i].isFinal) finalText += piece;
      else interim += piece;
    }
    const text = (finalText || interim).trim();
    if (!text) return;
    options.onChunk({
      text,
      isFinal: Boolean(finalText),
      sourceLang: recognition.lang,
      segmentId: `speech_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    });
  };
  recognition.onerror = () => {};
  recognition.onend = () => {
    if (!active) return;
    try {
      recognition.start();
    } catch {
    }
  };
  try {
    recognition.start();
  } catch {
  }
  return () => {
    active = false;
    recognition.onresult = null;
    recognition.onerror = null;
    recognition.onend = null;
    try {
      recognition.stop();
    } catch {
    }
  };
}
