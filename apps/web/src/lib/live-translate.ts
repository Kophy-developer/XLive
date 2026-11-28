import { normalizeLiveLang, type LiveLang, needsLiveTranslation } from "./live-languages";
import { LIVE_SEGMENT_MAX } from "./live-segments";

export type TranslateResponse = {
  text: string;
  translated: boolean;
  source?: string;
  target?: string;
  provider?: string;
};

const cache = new Map<string, string>();
let unlockAudio: HTMLAudioElement | null = null;
let playToken = 0;
let speakPumpRunning = false;
const speakQueue: Array<{
  text: string;
  lang: LiveLang;
  resolve: () => void;
}> = [];

export function windowLiveText(text: string, max = LIVE_SEGMENT_MAX): string {
  const t = text.trim();
  if (t.length <= max) return t;
  const sliced = t.slice(-max);
  const space = sliced.indexOf(" ");
  if (space > 0 && space < 64) return sliced.slice(space + 1).trim();
  return sliced.trim();
}

export async function translateLiveText(options: {
  text: string;
  source?: string | null;
  target?: string | null;
}): Promise<TranslateResponse> {
  const text = windowLiveText(options.text);
  const target = normalizeLiveLang(options.target) || "en";
  const source = normalizeLiveLang(options.source);
  if (!text) return { text: "", translated: false, target };
  if (source && source === target) {
    return { text, translated: false, source, target };
  }
  if (!needsLiveTranslation(source || null, target)) {
    return { text, translated: false, source: source || undefined, target };
  }

  const key = `${source || "auto"}|${target}|${text}`;
  const hit = cache.get(key);
  if (hit != null) {
    return { text: hit, translated: hit !== text, source: source || undefined, target, provider: "cache" };
  }

  try {
    const res = await fetch("/api/live/translate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        text,
        source: source || "auto",
        target,
      }),
    });
    if (!res.ok) {
      return { text, translated: false, source: source || undefined, target };
    }
    const data = (await res.json()) as TranslateResponse;
    const out = String(data.text || "").trim() || text;
    const didTranslate = Boolean(data.translated) && out !== text;
    if (didTranslate) {
      cache.set(key, out);
      if (cache.size > 200) {
        const first = cache.keys().next().value;
        if (first) cache.delete(first);
      }
    }
    return {
      text: didTranslate ? out : text,
      translated: didTranslate,
      source: normalizeLiveLang(data.source) || source || undefined,
      target,
      provider: data.provider,
    };
  } catch {
    return { text, translated: false, source: source || undefined, target };
  }
}

function pickVoice(lang: LiveLang): SpeechSynthesisVoice | null {
  if (typeof window === "undefined" || !window.speechSynthesis) return null;
  const voices = window.speechSynthesis.getVoices();
  if (!voices.length) return null;
  const prefixes: Record<LiveLang, string[]> = {
    en: ["en-US", "en-GB", "en"],
    es: ["es-ES", "es-MX", "es"],
    fr: ["fr-FR", "fr-CA", "fr"],
    zh: ["zh-CN", "zh-TW", "zh-HK", "zh", "cmn"],
  };
  for (const prefix of prefixes[lang]) {
    const match = voices.find((v) => {
      const code = (v.lang || "").toLowerCase().replace("_", "-");
      return code.startsWith(prefix.toLowerCase());
    });
    if (match) return match;
  }
  return voices[0] || null;
}

function splitTtsChunks(text: string, max = 160): string[] {
  const trimmed = text.trim();
  if (!trimmed) return [];
  if (trimmed.length <= max) return [trimmed];
  const parts: string[] = [];
  const sentences = trimmed.split(/(?<=[.!?。！？;:])\s+/);
  let buf = "";
  for (const sentence of sentences) {
    if (!sentence) continue;
    if ((buf + " " + sentence).trim().length <= max) {
      buf = (buf + " " + sentence).trim();
      continue;
    }
    if (buf) parts.push(buf);
    if (sentence.length <= max) {
      buf = sentence;
      continue;
    }
    let rest = sentence;
    while (rest.length > max) {
      let cut = rest.lastIndexOf(" ", max);
      if (cut < 40) cut = max;
      parts.push(rest.slice(0, cut).trim());
      rest = rest.slice(cut).trim();
    }
    buf = rest;
  }
  if (buf) parts.push(buf);
  return parts.filter(Boolean);
}

function ensureUnlockAudio(): HTMLAudioElement | null {
  if (typeof window === "undefined") return null;
  if (unlockAudio) return unlockAudio;
  const audio = new Audio();
  audio.setAttribute("playsinline", "true");
  audio.preload = "auto";
  unlockAudio = audio;
  return audio;
}

export function unlockLiveSpeech(): void {
  if (typeof window === "undefined") return;
  try {
    if (window.speechSynthesis) {
      window.speechSynthesis.cancel();
      const utter = new SpeechSynthesisUtterance(" ");
      utter.volume = 0;
      utter.rate = 2;
      window.speechSynthesis.speak(utter);
      window.speechSynthesis.cancel();
    }
  } catch {
  }
  try {
    const audio = ensureUnlockAudio();
    if (!audio) return;
    audio.src =
      "data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=";
    void audio.play().catch(() => {});
  } catch {
  }
}

const TTS_FETCH_TIMEOUT_MS = 12000;
const TTS_PLAY_TIMEOUT_MS = 20000;

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("timeout")), ms);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (err) => {
        clearTimeout(timer);
        reject(err);
      }
    );
  });
}

async function playAudioBlob(blob: Blob, token: number): Promise<void> {
  const audio = ensureUnlockAudio();
  if (!audio) return;
  const url = URL.createObjectURL(blob);
  try {
    if (token !== playToken) return;
    audio.pause();
    audio.src = url;
    await withTimeout(audio.play(), 4000);
    if (token !== playToken) return;
    await withTimeout(
      new Promise<void>((resolve) => {
        const done = () => {
          audio.removeEventListener("ended", done);
          audio.removeEventListener("error", done);
          resolve();
        };
        audio.addEventListener("ended", done);
        audio.addEventListener("error", done);
      }),
      TTS_PLAY_TIMEOUT_MS
    );
  } finally {
    URL.revokeObjectURL(url);
  }
}

function speakViaSpeechSynthesis(text: string, lang: LiveLang, token: number): Promise<void> {
  return new Promise((resolve) => {
    if (typeof window === "undefined" || !window.speechSynthesis) {
      resolve();
      return;
    }
    let settled = false;
    const finish = () => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve();
    };
    const timer = setTimeout(finish, TTS_PLAY_TIMEOUT_MS);
    try {
      if (token !== playToken) {
        finish();
        return;
      }
      const utter = new SpeechSynthesisUtterance(text);
      utter.lang =
        lang === "zh" ? "zh-CN" : lang === "es" ? "es-ES" : lang === "fr" ? "fr-FR" : "en-US";
      const voice = pickVoice(lang);
      if (voice) utter.voice = voice;
      utter.rate = 1.02;
      utter.onend = () => finish();
      utter.onerror = () => finish();
      window.speechSynthesis.speak(utter);
    } catch {
      finish();
    }
  });
}

async function playOneUtterance(text: string, lang: LiveLang, token: number): Promise<void> {
  const chunks = splitTtsChunks(text, 160);
  let played = false;
  for (const chunk of chunks) {
    if (token !== playToken) return;
    try {
      const res = await withTimeout(
        fetch("/api/live/tts", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text: chunk, lang }),
        }),
        TTS_FETCH_TIMEOUT_MS
      );
      if (!res.ok) continue;
      const blob = await withTimeout(res.blob(), TTS_FETCH_TIMEOUT_MS);
      if (!blob.size) continue;
      try {
        await playAudioBlob(blob, token);
        played = true;
      } catch {
        unlockLiveSpeech();
        try {
          await playAudioBlob(blob, token);
          played = true;
        } catch {
        }
      }
    } catch {
    }
  }
  if (!played && token === playToken) {
    await speakViaSpeechSynthesis(text, lang, token);
  }
}

async function pumpSpeakQueue(): Promise<void> {
  if (speakPumpRunning) return;
  speakPumpRunning = true;
  try {
    while (speakQueue.length) {
      const job = speakQueue.shift();
      if (!job) break;
      const token = playToken;
      unlockLiveSpeech();
      await playOneUtterance(job.text, job.lang, token);
      job.resolve();
    }
  } finally {
    speakPumpRunning = false;
    if (speakQueue.length) void pumpSpeakQueue();
  }
}

export function speakLiveTranslation(text: string, target?: string | null): Promise<void> {
  if (typeof window === "undefined") return Promise.resolve();
  const trimmed = text.trim();
  if (!trimmed) return Promise.resolve();
  const lang = normalizeLiveLang(target) || "en";
  return new Promise((resolve) => {
    speakQueue.push({ text: trimmed, lang, resolve });
    void pumpSpeakQueue();
  });
}

export function stopLiveSpeech(): void {
  playToken += 1;
  while (speakQueue.length) {
    const job = speakQueue.shift();
    job?.resolve();
  }
  if (typeof window === "undefined") return;
  try {
    if (unlockAudio) {
      unlockAudio.pause();
      unlockAudio.removeAttribute("src");
    }
  } catch {
  }
  try {
    window.speechSynthesis?.cancel();
  } catch {
  }
}

export function setRemoteAudioDucked(
  users: Array<{ audioTrack?: { setVolume?: (v: number) => void } | null }>,
  ducked: boolean
) {
  const volume = ducked ? 0 : 100;
  for (const user of users) {
    try {
      user.audioTrack?.setVolume?.(volume);
    } catch {
    }
  }
}
