export const LIVE_LANGS = ["en", "es", "fr", "zh"] as const;
export type LiveLang = (typeof LIVE_LANGS)[number];

const SPEECH_LOCALE: Record<LiveLang, string> = {
  en: "en-US",
  es: "es-ES",
  fr: "fr-FR",
  zh: "zh-CN",
};

export function normalizeLiveLang(input?: string | null): LiveLang | "" {
  if (!input) return "";
  const raw = input.trim().toLowerCase().replace("_", "-");
  if (!raw) return "";
  const base = raw.split("-")[0] || "";
  if (base === "zh" || raw.startsWith("zh") || raw.includes("cmn") || raw.includes("mandarin")) {
    return "zh";
  }
  if ((LIVE_LANGS as readonly string[]).includes(base)) return base as LiveLang;
  return "";
}

export function speechLocaleForLang(input?: string | null): string {
  const lang = normalizeLiveLang(input) || "en";
  return SPEECH_LOCALE[lang];
}

export function needsLiveTranslation(source?: string | null, target?: string | null): boolean {
  const from = normalizeLiveLang(source);
  const to = normalizeLiveLang(target);
  if (!to) return false;
  if (!from) return true;
  return from !== to;
}
