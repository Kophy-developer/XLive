import assert from "node:assert/strict";
import {
  LIVE_SEGMENT_MAX,
  LIVE_SEGMENT_MIN,
  LIVE_WINDOW_HARD_MS,
  alignCommitCursor,
  endsOnDanglingWord,
  extractClosableSegments,
  isSenseComplete,
  pendingAfterCommitted,
  tokenizeLiveWords,
} from "./live-segments";

const long =
  "el pequeño pueblo de San Lorenzo se encontraba enclavado entre las colinas del norte. un lugar donde el tiempo parecía transcurrir a un ritmo mucho más lento que en las grandes ciudades. las calles empedradas y serpenteantes subían y bajaban entre casas de piedra.";

const bySentence = extractClosableSegments(long, { reason: "interim" });
assert.ok(bySentence.closed.length >= 2);

const senseReady = extractClosableSegments(
  "el pequeño pueblo de San Lorenzo se encontraba",
  { reason: "sense" }
);
assert.equal(senseReady.closed.length, 1);
assert.equal(senseReady.rest, "");
assert.equal(isSenseComplete(senseReady.closed[0]), true);

const crumb = extractClosableSegments("I am", { reason: "sense" });
assert.equal(crumb.closed.length, 0);
assert.equal(endsOnDanglingWord("I am"), true);

const danglingHold = extractClosableSegments("el pequeño pueblo de", { reason: "sense" });
assert.equal(danglingHold.closed.length, 0);

const hardCut = extractClosableSegments(
  "el pequeño pueblo de San Lorenzo se encontraba enclavado entre las colinas",
  { reason: "hard" }
);
assert.equal(hardCut.closed.length, 1);

assert.equal(pendingAfterCommitted("hola mundo cruel", "hola mundo"), "cruel");
assert.equal(
  pendingAfterCommitted(
    "El pequeño pueblo de San Lorenzo se encontraba entre las colinas",
    "el pequeño pueblo de San Lorenzo se encontraba entre las"
  ),
  "colinas"
);
assert.equal(
  pendingAfterCommitted(
    "el pueblo cambiado por completo desde el inicio",
    "texto viejo que ya no aparece en el stream"
  ),
  ""
);

const snap = tokenizeLiveWords(
  "el pequeño pueblo de San Lorenzo se encontraba enclavado entre las colinas del norte un lugar"
);
const committed = tokenizeLiveWords(
  "el pequeño pueblo de San Lorenzo se encontraba enclavado entre las colinas del norte"
);
const cursor = alignCommitCursor(snap, committed);
assert.equal(cursor, committed.length);
assert.equal(snap.slice(cursor).join(" "), "un lugar");

const rewritten = tokenizeLiveWords(
  "El Pequeño Pueblo de San Lorenzo se encontraba enclavado entre las colinas del norte un lugar"
);
assert.equal(alignCommitCursor(rewritten, committed), committed.length);

assert.equal(LIVE_SEGMENT_MAX, 490);
assert.ok(LIVE_SEGMENT_MIN <= 20);
assert.equal(LIVE_WINDOW_HARD_MS, 3000);

console.log("live-segments.test.ts ok", {
  senseClosed: senseReady.closed[0],
  cursor,
  hardMs: LIVE_WINDOW_HARD_MS,
});
