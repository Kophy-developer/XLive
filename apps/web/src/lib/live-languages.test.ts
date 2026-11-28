import assert from "node:assert/strict";
import { needsLiveTranslation, normalizeLiveLang, speechLocaleForLang } from "./live-languages";

assert.equal(normalizeLiveLang("en-US"), "en");
assert.equal(normalizeLiveLang("ES"), "es");
assert.equal(normalizeLiveLang("fr_FR"), "fr");
assert.equal(normalizeLiveLang("zh-CN"), "zh");
assert.equal(normalizeLiveLang("zh-Hans"), "zh");
assert.equal(normalizeLiveLang("mandarin"), "zh");
assert.equal(normalizeLiveLang("de"), "");

assert.equal(speechLocaleForLang("es"), "es-ES");
assert.equal(speechLocaleForLang("zh"), "zh-CN");
assert.equal(speechLocaleForLang("en"), "en-US");
assert.equal(speechLocaleForLang("fr"), "fr-FR");

assert.equal(needsLiveTranslation("es", "en"), true);
assert.equal(needsLiveTranslation("en", "en"), false);
assert.equal(needsLiveTranslation("zh-CN", "fr"), true);
assert.equal(needsLiveTranslation("", "en"), true);
assert.equal(needsLiveTranslation("es", ""), false);

const matrix = ["en", "es", "fr", "zh"] as const;
for (const source of matrix) {
  for (const target of matrix) {
    const needed = needsLiveTranslation(source, target);
    assert.equal(needed, source !== target, `${source}->${target}`);
  }
}

console.log("live-languages matrix ok");
