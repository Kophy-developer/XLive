import { normalizeLiveLang, speechLocaleForLang } from "./live-languages";
import {
  LIVE_PAUSE_FLUSH_MS,
  LIVE_SEGMENT_MIN,
  LIVE_WINDOW_HARD_MS,
  LIVE_WINDOW_SOFT_MS,
  alignCommitCursor,
  extractClosableSegments,
  tokenizeLiveWords,
  type LiveCloseReason,
} from "./live-segments";
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
  const sourceLang = normalizeLiveLang(chunk.sourceLang) || chunk.sourceLang;
  emitSocket("stream_transcript_chunk", {
    streamId,
    segmentId: chunk.segmentId,
    text,
    sourceLang: sourceLang || undefined,
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

function startHostGroqCaptions(options: {
  lang?: string;
  onChunk: (chunk: CaptionChunk) => void;
}): () => void {
  let active = true;
  let media: MediaStream | null = null;
  let recorder: MediaRecorder | null = null;
  let timer: ReturnType<typeof setInterval> | null = null;
  const sourceLang = normalizeLiveLang(options.lang) || "en";

  const flush = async (blob: Blob) => {
    if (!active || blob.size < 1200) return;
    try {
      const form = new FormData();
      form.append("file", blob, `chunk-${Date.now()}.webm`);
      form.append("language", sourceLang);
      const res = await fetch("/api/live/transcribe", { method: "POST", body: form });
      if (!res.ok) return;
      const data = (await res.json()) as { text?: string };
      const text = String(data.text || "").trim();
      if (!text || !active) return;
      options.onChunk({
        text,
        isFinal: true,
        sourceLang,
        segmentId: `groq_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
      });
    } catch {
    }
  };

  void (async () => {
    try {
      media = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true },
        video: false,
      });
      if (!active) {
        media.getTracks().forEach((t) => t.stop());
        return;
      }
      const mime = MediaRecorder.isTypeSupported("audio/webm;codecs=opus")
        ? "audio/webm;codecs=opus"
        : MediaRecorder.isTypeSupported("audio/webm")
        ? "audio/webm"
        : "";
      recorder = mime ? new MediaRecorder(media, { mimeType: mime }) : new MediaRecorder(media);
      let parts: BlobPart[] = [];
      recorder.ondataavailable = (ev) => {
        if (ev.data && ev.data.size > 0) parts.push(ev.data);
      };
      recorder.onstop = () => {
        const blob = new Blob(parts, { type: recorder?.mimeType || "audio/webm" });
        parts = [];
        void flush(blob);
        if (active && recorder && media) {
          try {
            recorder.start();
          } catch {
          }
        }
      };
      recorder.start();
      timer = setInterval(() => {
        if (!active || !recorder || recorder.state !== "recording") return;
        try {
          recorder.stop();
        } catch {
        }
      }, 3200);
    } catch {
    }
  })();

  return () => {
    active = false;
    if (timer) clearInterval(timer);
    try {
      if (recorder && recorder.state !== "inactive") recorder.stop();
    } catch {
    }
    media?.getTracks().forEach((t) => t.stop());
    recorder = null;
    media = null;
  };
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
  if (!SpeechRecognition) {
    return startHostGroqCaptions(options);
  }

  let active = true;
  let sessionFinals = "";
  let lastInterim = "";
  let lastOpenEmit = "";
  let segSeq = 0;
  let committedWords: string[] = [];
  let pauseTimer: ReturnType<typeof setTimeout> | null = null;
  let softTimer: ReturnType<typeof setTimeout> | null = null;
  let hardTimer: ReturnType<typeof setTimeout> | null = null;
  let windowArmed = false;
  const recognition = new SpeechRecognition();
  recognition.continuous = true;
  recognition.interimResults = true;
  recognition.lang = speechLocaleForLang(options.lang);
  const sourceLang = normalizeLiveLang(options.lang) || normalizeLiveLang(recognition.lang) || "en";

  const clearWindowTimers = () => {
    if (softTimer) clearTimeout(softTimer);
    if (hardTimer) clearTimeout(hardTimer);
    softTimer = null;
    hardTimer = null;
    windowArmed = false;
  };

  const snapshotText = () =>
    `${sessionFinals}${lastInterim ? ` ${lastInterim}` : ""}`.replace(/\s+/g, " ").trim();

  const pendingAfterCursor = () => {
    const words = tokenizeLiveWords(snapshotText());
    const cursor = alignCommitCursor(words, committedWords);
    committedWords = words.slice(0, cursor);
    return words.slice(cursor).join(" ").trim();
  };

  const emitFinalSeg = (seg: string) => {
    const text = seg.replace(/\s+/g, " ").trim();
    if (text.length < LIVE_SEGMENT_MIN) return false;
    const words = tokenizeLiveWords(text);
    if (!words.length) return false;
    segSeq += 1;
    committedWords = committedWords.concat(words);
    options.onChunk({
      text,
      isFinal: true,
      sourceLang,
      segmentId: `speech_${segSeq}_${Date.now()}`,
    });
    lastOpenEmit = "";
    return true;
  };

  const emitOpen = (text: string) => {
    const cleaned = text.replace(/\s+/g, " ").trim();
    if (!cleaned || cleaned === lastOpenEmit) return;
    lastOpenEmit = cleaned;
    options.onChunk({
      text: cleaned,
      isFinal: false,
      sourceLang,
      segmentId: `speech_open_${segSeq}`,
    });
  };

  const publishPending = (reason: LiveCloseReason) => {
    const pending = pendingAfterCursor();
    if (!pending) {
      clearWindowTimers();
      return;
    }
    const { closed, rest } = extractClosableSegments(pending, { reason });
    let emitted = 0;
    const held: string[] = [];
    for (const seg of closed) {
      if (emitFinalSeg(seg)) emitted += 1;
      else held.push(seg);
    }
    const open = [...held, rest].filter(Boolean).join(" ").replace(/\s+/g, " ").trim();
    if (open) emitOpen(open);
    else lastOpenEmit = "";
    if (!pendingAfterCursor()) {
      clearWindowTimers();
    } else if (emitted > 0) {
      clearWindowTimers();
      armWindowTimers();
    }
  };

  const armWindowTimers = () => {
    if (windowArmed || !active) return;
    if (!pendingAfterCursor()) return;
    windowArmed = true;
    softTimer = setTimeout(() => {
      softTimer = null;
      if (!active) return;
      publishPending("soft");
    }, LIVE_WINDOW_SOFT_MS);
    hardTimer = setTimeout(() => {
      hardTimer = null;
      if (!active) return;
      publishPending("hard");
    }, LIVE_WINDOW_HARD_MS);
  };

  const armPauseFlush = () => {
    if (pauseTimer) clearTimeout(pauseTimer);
    pauseTimer = setTimeout(() => {
      pauseTimer = null;
      if (!active) return;
      publishPending("pause");
    }, LIVE_PAUSE_FLUSH_MS);
  };

  recognition.onresult = (event) => {
    let interim = "";
    let newFinals = "";
    for (let i = event.resultIndex; i < event.results.length; i++) {
      const piece = event.results[i][0]?.transcript || "";
      if (event.results[i].isFinal) newFinals += piece;
      else interim += piece;
    }
    if (newFinals.trim()) {
      sessionFinals = `${sessionFinals} ${newFinals}`.replace(/\s+/g, " ").trim();
    }
    lastInterim = interim.replace(/\s+/g, " ").trim();
    if (!snapshotText()) return;
    publishPending(newFinals.trim() ? "stt_final" : "sense");
    armWindowTimers();
    armPauseFlush();
  };
  recognition.onerror = () => {};
  recognition.onend = () => {
    if (!active) return;
    publishPending("pause");
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
    if (pauseTimer) clearTimeout(pauseTimer);
    clearWindowTimers();
    recognition.onresult = null;
    recognition.onerror = null;
    recognition.onend = null;
    try {
      recognition.stop();
    } catch {
    }
  };
}
