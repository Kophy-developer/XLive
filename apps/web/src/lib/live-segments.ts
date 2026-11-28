export const LIVE_SEGMENT_MAX = 490;
export const LIVE_SEGMENT_MIN = 20;
export const LIVE_SENSE_MIN_WORDS = 5;
export const LIVE_WINDOW_SOFT_MS = 2500;
export const LIVE_WINDOW_HARD_MS = 3000;
export const LIVE_PAUSE_FLUSH_MS = 500;

const SENTENCE_END = /[.!?。！？](?:["'”’)\]…]*)?(?:\s+|$)/;

const DANGLING_WORDS = new Set([
  "a",
  "an",
  "the",
  "to",
  "of",
  "in",
  "on",
  "at",
  "for",
  "and",
  "or",
  "but",
  "if",
  "as",
  "by",
  "with",
  "from",
  "into",
  "my",
  "your",
  "his",
  "her",
  "our",
  "their",
  "i",
  "i'm",
  "im",
  "am",
  "is",
  "are",
  "was",
  "were",
  "be",
  "been",
  "being",
  "we",
  "you",
  "he",
  "she",
  "it",
  "they",
  "this",
  "that",
  "these",
  "those",
  "not",
  "do",
  "does",
  "did",
  "will",
  "would",
  "can",
  "could",
  "should",
  "have",
  "has",
  "had",
  "el",
  "la",
  "los",
  "las",
  "un",
  "una",
  "unos",
  "unas",
  "de",
  "del",
  "al",
  "en",
  "con",
  "por",
  "para",
  "y",
  "o",
  "que",
  "si",
  "mi",
  "tu",
  "su",
  "me",
  "te",
  "se",
  "nos",
  "es",
  "son",
  "esta",
  "está",
  "estan",
  "están",
  "ser",
  "estar",
  "yo",
  "tú",
  "él",
  "ella",
  "nosotros",
  "ellos",
  "ellas",
  "le",
  "les",
  "des",
  "du",
  "au",
  "aux",
  "avec",
  "pour",
  "par",
  "et",
  "ou",
  "qui",
  "je",
  "il",
  "nous",
  "vous",
  "ils",
  "est",
  "sont",
  "être",
  "ce",
  "cet",
  "cette",
  "ces",
  "mon",
  "ton",
  "son",
]);

export type LiveCloseReason = "soft" | "hard" | "pause" | "stt_final" | "interim" | "sense";

export function tokenizeLiveWords(text: string): string[] {
  return text
    .trim()
    .replace(/\s+/g, " ")
    .split(" ")
    .filter(Boolean);
}

export function normalizeLiveWord(word: string): string {
  return word
    .toLowerCase()
    .replace(/^[^A-Za-zÁÉÍÓÚÜÑáéíóúüñÀÂÄÈÉÊËÎÏÔŒÙÛÜŸÇàâäèéêëîïôœùûüÿç']+|[^A-Za-zÁÉÍÓÚÜÑáéíóúüñÀÂÄÈÉÊËÎÏÔŒÙÛÜŸÇàâäèéêëîïôœùûüÿç']+$/g, "");
}

export function alignCommitCursor(snapshotWords: string[], committedWords: string[]): number {
  if (!committedWords.length) return 0;
  const snap = snapshotWords.map(normalizeLiveWord);
  const done = committedWords.map(normalizeLiveWord);
  let i = 0;
  while (i < done.length && i < snap.length && done[i] === snap[i]) i += 1;
  if (i === done.length) return i;
  if (i > 0) return i;

  for (let n = Math.min(done.length, 8); n >= 2; n -= 1) {
    const needle = done.slice(done.length - n);
    for (let s = 0; s <= snap.length - n; s += 1) {
      let ok = true;
      for (let j = 0; j < n; j += 1) {
        if (snap[s + j] !== needle[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return s + n;
    }
  }

  return Math.min(done.length, snap.length);
}

export function splitLiveSegments(text: string, max = LIVE_SEGMENT_MAX): string[] {
  const t = text.trim();
  if (!t) return [];
  const out: string[] = [];
  let rest = t;
  while (rest.length > max) {
    const window = rest.slice(0, max + 1);
    let cut = -1;
    const sentenceCut = Math.max(
      window.lastIndexOf(". "),
      window.lastIndexOf("? "),
      window.lastIndexOf("! "),
      window.lastIndexOf("。"),
      window.lastIndexOf("！"),
      window.lastIndexOf("？")
    );
    if (sentenceCut >= Math.floor(max * 0.4)) {
      cut = sentenceCut + 1;
    } else {
      cut = window.lastIndexOf(" ");
      if (cut < Math.floor(max * 0.4)) cut = max;
    }
    const piece = rest.slice(0, cut).trim();
    if (piece) out.push(piece);
    rest = rest.slice(cut).trim();
  }
  if (rest) out.push(rest);
  return out;
}

export function latestLiveSegment(text: string, max = LIVE_SEGMENT_MAX): string {
  const parts = splitLiveSegments(text, max);
  return parts[parts.length - 1] || text.trim();
}

export function pendingAfterCommitted(latest: string, committed: string): string {
  const fullWords = tokenizeLiveWords(latest);
  const doneWords = tokenizeLiveWords(committed);
  const cursor = alignCommitCursor(fullWords, doneWords);
  return fullWords.slice(cursor).join(" ").trim();
}

function endsWithSentence(text: string): boolean {
  return /[.!?。！？]["'”’)\]…]*\s*$/.test(text.trim());
}

function lastWordComplete(text: string): boolean {
  const t = text.trim();
  if (!t) return false;
  if (endsWithSentence(t)) return true;
  return /\s|[.!?。！？]$/.test(t) || !/[A-Za-zÁÉÍÓÚÜÑáéíóúüñÀÂÄÈÉÊËÎÏÔŒÙÛÜŸÇàâäèéêëîïôœùûüÿç]$/.test(t);
}

export function liveSegmentWordCount(text: string): number {
  return tokenizeLiveWords(text).length;
}

export function endsOnDanglingWord(text: string): boolean {
  const words = tokenizeLiveWords(text);
  if (!words.length) return false;
  const last = normalizeLiveWord(words[words.length - 1] || "");
  return Boolean(last) && DANGLING_WORDS.has(last);
}

export function isSenseComplete(text: string): boolean {
  const t = text.trim();
  if (!t) return false;
  if (endsWithSentence(t)) return true;
  const words = liveSegmentWordCount(t);
  if (endsOnDanglingWord(t)) return false;
  if (words >= LIVE_SENSE_MIN_WORDS) return true;
  return words >= 4 && t.length >= 24;
}

export function isSoftComplete(text: string): boolean {
  return isSenseComplete(text);
}

function cutBeforeDangling(text: string, min: number): { closed: string; rest: string } | null {
  const words = tokenizeLiveWords(text);
  if (words.length < 2) return null;
  let end = words.length;
  while (end > 0) {
    const word = normalizeLiveWord(words[end - 1] || "");
    if (!word || !DANGLING_WORDS.has(word)) break;
    end -= 1;
  }
  if (end <= 0 || end >= words.length) return null;
  const closed = words.slice(0, end).join(" ").trim();
  const rest = words.slice(end).join(" ").trim();
  if (closed.length < Math.floor(min * 0.6) && liveSegmentWordCount(closed) < 4) return null;
  return { closed, rest };
}

export function extractClosableSegments(
  pending: string,
  options?: { force?: boolean; max?: number; min?: number; reason?: LiveCloseReason }
): { closed: string[]; rest: string } {
  const max = options?.max ?? LIVE_SEGMENT_MAX;
  const min = options?.min ?? LIVE_SEGMENT_MIN;
  const reason = options?.reason;
  const force =
    options?.force === true ||
    reason === "hard" ||
    reason === "pause" ||
    (reason === "soft" && isSenseComplete(pending)) ||
    (reason === "sense" && isSenseComplete(pending)) ||
    (reason === "interim" && isSenseComplete(pending)) ||
    (reason === "stt_final" && isSenseComplete(pending));
  let rest = pending.replace(/\s+/g, " ").trim();
  if (!rest) return { closed: [], rest: "" };

  const closed: string[] = [];

  while (true) {
    const match = rest.match(SENTENCE_END);
    if (!match || match.index == null) break;
    const end = match.index + match[0].length;
    const piece = rest.slice(0, end).trim();
    if (piece.length >= Math.min(min, 12)) {
      closed.push(piece);
      rest = rest.slice(end).trim();
      continue;
    }
    break;
  }

  while (rest.length > max) {
    const window = rest.slice(0, max + 1);
    let cut = window.lastIndexOf(" ");
    if (cut < Math.floor(max * 0.45)) cut = max;
    const piece = rest.slice(0, cut).trim();
    if (!piece) break;
    closed.push(piece);
    rest = rest.slice(cut).trim();
  }

  if (!force || !rest) {
    return { closed: closed.filter(Boolean), rest };
  }

  if (
    (reason === "soft" || reason === "sense" || reason === "interim" || reason === "stt_final") &&
    !isSenseComplete(rest)
  ) {
    return { closed: closed.filter(Boolean), rest };
  }

  if (endsOnDanglingWord(rest)) {
    const trimmed = cutBeforeDangling(rest, min);
    if (trimmed) {
      closed.push(trimmed.closed);
      rest = trimmed.rest;
      return { closed: closed.filter(Boolean), rest };
    }
    if (reason === "soft" || reason === "sense" || reason === "interim" || reason === "stt_final") {
      return { closed: closed.filter(Boolean), rest };
    }
  }

  if (rest.length >= min && lastWordComplete(rest)) {
    closed.push(rest.trim());
    rest = "";
  } else if (rest.length >= min) {
    const cut = rest.lastIndexOf(" ");
    if (cut >= Math.floor(min * 0.6)) {
      closed.push(rest.slice(0, cut).trim());
      rest = rest.slice(cut).trim();
    }
  } else if (reason === "hard" && liveSegmentWordCount(rest) >= 4 && lastWordComplete(rest)) {
    closed.push(rest.trim());
    rest = "";
  }

  return { closed: closed.filter(Boolean), rest };
}
