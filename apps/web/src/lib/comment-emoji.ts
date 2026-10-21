export const COMMENT_EMOJI_PACK: { code: string; glyph: string }[] = [
  { code: "grin", glyph: "😀" },
  { code: "smiley", glyph: "😃" },
  { code: "smile", glyph: "😄" },
  { code: "laugh", glyph: "😆" },
  { code: "joy", glyph: "😂" },
  { code: "rofl", glyph: "🤣" },
  { code: "wink", glyph: "😉" },
  { code: "blush", glyph: "😊" },
  { code: "innocent", glyph: "😇" },
  { code: "hearts", glyph: "🥰" },
  { code: "heart_eyes", glyph: "😍" },
  { code: "star_struck", glyph: "🤩" },
  { code: "kiss", glyph: "😘" },
  { code: "think", glyph: "🤔" },
  { code: "shush", glyph: "🤫" },
  { code: "neutral", glyph: "😐" },
  { code: "expressionless", glyph: "😑" },
  { code: "smirk", glyph: "😏" },
  { code: "unamused", glyph: "😒" },
  { code: "roll", glyph: "🙄" },
  { code: "sleep", glyph: "😴" },
  { code: "sick", glyph: "🤒" },
  { code: "hot", glyph: "🥵" },
  { code: "cold", glyph: "🥶" },
  { code: "woozy", glyph: "🥴" },
  { code: "exploding", glyph: "🤯" },
  { code: "party", glyph: "🥳" },
  { code: "cool", glyph: "😎" },
  { code: "nerd", glyph: "🤓" },
  { code: "confused", glyph: "😕" },
  { code: "worried", glyph: "😟" },
  { code: "open_mouth", glyph: "😮" },
  { code: "hush", glyph: "😯" },
  { code: "astonished", glyph: "😲" },
  { code: "flush", glyph: "😳" },
  { code: "pleading", glyph: "🥺" },
  { code: "frown", glyph: "😢" },
  { code: "sob", glyph: "😭" },
  { code: "scream", glyph: "😱" },
  { code: "rage", glyph: "😡" },
  { code: "thumbsup", glyph: "👍" },
  { code: "thumbsdown", glyph: "👎" },
  { code: "clap", glyph: "👏" },
  { code: "pray", glyph: "🙏" },
  { code: "ok", glyph: "👌" },
  { code: "muscle", glyph: "💪" },
  { code: "fire", glyph: "🔥" },
  { code: "hundred", glyph: "💯" },
  { code: "sparkles", glyph: "✨" },
  { code: "star", glyph: "⭐" },
  { code: "boom", glyph: "💥" },
  { code: "heart", glyph: "❤️" },
  { code: "orange_heart", glyph: "🧡" },
  { code: "yellow_heart", glyph: "💛" },
  { code: "green_heart", glyph: "💚" },
  { code: "blue_heart", glyph: "💙" },
  { code: "purple_heart", glyph: "💜" },
  { code: "black_heart", glyph: "🖤" },
  { code: "white_heart", glyph: "🤍" },
  { code: "broken_heart", glyph: "💔" },
  { code: "two_hearts", glyph: "💕" },
  { code: "tada", glyph: "🎉" },
  { code: "crown", glyph: "👑" },
  { code: "trophy", glyph: "🏆" },
  { code: "rose", glyph: "🌹" },
  { code: "sun", glyph: "☀️" },
  { code: "moon", glyph: "🌙" },
  { code: "dog", glyph: "🐶" },
  { code: "cat", glyph: "🐱" },
  { code: "unicorn", glyph: "🦄" },
  { code: "pizza", glyph: "🍕" },
  { code: "burger", glyph: "🍔" },
  { code: "coffee", glyph: "☕" },
  { code: "music", glyph: "🎵" },
  { code: "camera", glyph: "📷" },
  { code: "gift", glyph: "🎁" },
  { code: "money", glyph: "💰" },
  { code: "eyes", glyph: "👀" },
  { code: "wave", glyph: "👋" },
  { code: "peace", glyph: "✌️" },
];

const TOKEN_RE = /\[\[xl:(e|r):([a-z0-9_]+)(?::[^\]]+)?\]\]/g;
const REACTION_RE = /^\[\[xl:r:([a-z0-9_]+)(?::([^\]]+))?\]\]$/;

const byCode = new Map(COMMENT_EMOJI_PACK.map((item) => [item.code, item.glyph]));
const byGlyph = [...COMMENT_EMOJI_PACK].sort((a, b) => b.glyph.length - a.glyph.length);

export function encodeCommentText(raw: string): string {
  let out = raw;
  for (const item of byGlyph) {
    if (!out.includes(item.glyph)) continue;
    out = out.split(item.glyph).join(`[[xl:e:${item.code}]]`);
  }
  return out;
}

export function decodeCommentText(raw: string): string {
  return String(raw || "").replace(TOKEN_RE, (_m, _kind, code: string) => byCode.get(code) || "");
}

export function emojiToken(code: string, kind: "e" | "r" = "e"): string {
  return `[[xl:${kind}:${code}]]`;
}

export function reactionToken(code: string, parentId: string): string {
  return `[[xl:r:${code}:${parentId}]]`;
}

export function parseReaction(raw: string): { code: string; parentId?: string } | null {
  const match = String(raw || "").trim().match(REACTION_RE);
  if (!match) return null;
  return { code: match[1], parentId: match[2] || undefined };
}

export function reactionCodeFromContent(raw: string): string | null {
  return parseReaction(raw)?.code ?? null;
}

export function isReactionComment(raw: string): boolean {
  return parseReaction(raw) != null;
}

export function glyphForCode(code: string): string {
  return byCode.get(code) || "";
}

export const QUICK_REACTION_CODES = [
  "heart",
  "thumbsup",
  "joy",
  "open_mouth",
  "frown",
  "fire",
  "clap",
  "tada",
] as const;

export function codeForGlyph(glyph: string): string | null {
  const found = COMMENT_EMOJI_PACK.find((item) => item.glyph === glyph);
  return found ? found.code : null;
}

const MEDIA_RE = /\[\[xl:m:([^\]]+)\]\]/g;
const BARE_GIF_RE = /https?:\/\/(?:media[0-9]*\.|i\.)?(?:giphy\.com|tenor\.com)[^\s\]]+/gi;

export function extractMediaUrls(raw: string): string[] {
  const text = String(raw || "");
  const fromToken = Array.from(text.matchAll(MEDIA_RE)).map((m) => m[1].trim()).filter(Boolean);
  if (fromToken.length) return fromToken;
  return Array.from(text.matchAll(BARE_GIF_RE)).map((m) => m[0].trim());
}

export function textWithoutMedia(raw: string): string {
  return decodeCommentText(String(raw || "").replace(MEDIA_RE, " ")).replace(/\s+/g, " ").trim();
}

export function mediaToken(url: string) {
  return `[[xl:m:${url.trim()}]]`;
}

export function composeCommentContent(caption: string, mediaUrl?: string) {
  const text = encodeCommentText(caption.trim());
  if (!mediaUrl) return text;
  return text ? `${text} ${mediaToken(mediaUrl)}` : mediaToken(mediaUrl);
}
