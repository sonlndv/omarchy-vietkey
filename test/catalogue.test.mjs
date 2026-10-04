// Run with: node --test test/
import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import * as C from "../Catalogue.mjs"

const group = (...names) => names.map(name => ({ name, layout: "" }))

test("badge codes for every catalogue entry", () => {
  const badges = Object.fromEntries(C.LANGUAGES.map(l => [l.id, l.badge]))
  assert.deepEqual(badges, {
    en: "EN", vi: "VI", ja: "JA", ko: "KO", "zh-Hans": "ZH", "zh-Hant": "ZH", th: "TH"
  })
  assert.equal(C.badgeFor("keyboard-us"), "EN")
  assert.equal(C.badgeFor("keyboard-de"), "EN")
  assert.equal(C.badgeFor("unikey"), "VI")
  assert.equal(C.badgeFor("mozc"), "JA")
  assert.equal(C.badgeFor("hangul"), "KO")
  assert.equal(C.badgeFor("pinyin"), "ZH")
  assert.equal(C.badgeFor("chewing"), "ZH")
  assert.equal(C.badgeFor("libthai"), "TH")
  assert.equal(C.badgeFor(""), "EN")
  assert.equal(C.badgeFor("m17n_hi_inscript"), "HI")
})

test("layout languages: badge, nativeName, keyboard-<xkb> engine, no package", () => {
  const rows = Object.fromEntries(C.LAYOUT_LANGUAGES.map(l => [l.id, [l.badge, l.engines[0], l.package]]))
  assert.deepEqual(rows, {
    "ar-kbd": ["AR", "keyboard-ara", ""],
    "fa-kbd": ["FA", "keyboard-ir", ""],
    "he-kbd": ["HE", "keyboard-il", ""],
    "ru-kbd": ["RU", "keyboard-ru", ""],
    "uk-kbd": ["UK", "keyboard-ua", ""],
    "el-kbd": ["EL", "keyboard-gr", ""],
    "hi-kbd": ["HI", "keyboard-in", ""],
    "th-kbd": ["TH", "keyboard-th", ""]
  })
  for (const language of C.LAYOUT_LANGUAGES) {
    assert.ok(language.nativeName.length > 0, language.id + " needs a nativeName")
    assert.equal(C.badgeFor(language.engines[0]), language.badge)
  }
  assert.equal(C.OTHER_LAYOUT.package, "")
  assert.equal(C.OTHER_LAYOUT.engines.length, 0)
})

test("layout language engines are never treated as English (the keyboard-* bug)", () => {
  for (const language of C.LAYOUT_LANGUAGES) {
    const engine = language.engines[0]
    assert.equal(C.isEnglishEngine(engine), false, engine + " must not be English")
    assert.equal(C.languageForEngine(engine).id, language.id)
    assert.notEqual(C.badgeFor(engine), "EN")
  }
  // The user's own base layout (not one of ours) still counts as English.
  assert.equal(C.isEnglishEngine("keyboard-us"), true)
  assert.equal(C.isEnglishEngine("keyboard-de"), true)
})

test("layout languages merge into the group and keep order like any other language", () => {
  const existing = group("keyboard-us", "unikey")
  const merged = C.mergeGroup(existing, ["keyboard-ara", "keyboard-ru"])
  assert.deepEqual(merged.map(i => i.name), ["keyboard-us", "unikey", "keyboard-ara", "keyboard-ru"])
  // Existing entries are untouched and not reordered.
  assert.deepEqual(merged.slice(0, 2), existing)
  // Idempotent: merging again adds nothing new.
  assert.deepEqual(C.mergeGroup(merged, ["keyboard-ara"]), merged)
  const langs = C.languagesInGroup(group("keyboard-us", "keyboard-ara", "keyboard-il"))
  assert.deepEqual(langs.map(l => l.id), ["en", "ar-kbd", "he-kbd"])
})

test("catalogue packages and engines match SPEC §2", () => {
  const rows = Object.fromEntries(C.LANGUAGES.map(l => [l.id, [l.package, l.engines[0]]]))
  assert.deepEqual(rows, {
    en: ["", "keyboard-us"],
    vi: ["fcitx5-unikey", "unikey"],
    ja: ["fcitx5-mozc", "mozc"],
    ko: ["fcitx5-hangul", "hangul"],
    "zh-Hans": ["fcitx5-chinese-addons", "pinyin"],
    "zh-Hant": ["fcitx5-chewing", "chewing"],
    th: ["fcitx5-libthai", "libthai"]
  })
  assert.equal(C.OTHER.package, "fcitx5-m17n")
})

test("badge mode: Telex/VNI for Unikey, input style for Chinese, none for English", () => {
  assert.equal(C.badgeMode("unikey", { InputMethod: "VNI" }), "VNI")
  assert.equal(C.badgeMode("unikey", {}), "Telex")
  assert.equal(C.badgeMode("pinyin", {}), "Pinyin")
  assert.equal(C.badgeMode("chewing", {}), "Zhuyin")
  assert.equal(C.badgeMode("keyboard-us", {}), "")
  assert.equal(C.badgeMode("hangul", {}), "")
})

test("default selection is exactly English + Vietnamese", () => {
  assert.deepEqual(new Set(C.defaultSelection()), new Set(["en", "vi"]))
  assert.equal(C.defaultSelection().length, 2)
  // First run (only English in the group) pre-ticks Vietnamese.
  assert.deepEqual(C.initialSelection(group("keyboard-us")), ["en", "vi"])
  assert.deepEqual(C.initialSelection([]), ["en", "vi"])
  // Later, the picker starts from what is already in the group.
  assert.deepEqual(C.initialSelection(group("keyboard-us", "mozc")), ["en", "ja"])
})

test("English is always on and can't be removed; Vietnamese can be unticked", () => {
  assert.deepEqual(C.toggleSelection(["en", "vi"], "en"), ["en", "vi"])
  assert.deepEqual(C.toggleSelection(["en", "vi"], "vi"), ["en"])
  assert.deepEqual(C.toggleSelection(["en"], "ja"), ["en", "ja"])
  assert.deepEqual(C.normalizeSelection(["vi", "ja"]), ["en", "vi", "ja"])
  assert.deepEqual(C.normalizeSelection(["vi", "vi", "xx"]), ["en", "vi"])
  assert.deepEqual(C.toggleSelection(["en", "vi"], "nope"), ["en", "vi"])
})

test("packages: only missing ones, no duplicates, nothing for English", () => {
  assert.deepEqual(C.packagesFor(["en", "vi", "ja"], ["fcitx5-unikey"]), ["fcitx5-mozc"])
  assert.deepEqual(C.packagesFor(["en"], []), [])
  assert.deepEqual(C.enginesFor(["en", "vi", "other"]), ["keyboard-us", "unikey"])
})

test("group merge appends missing engines and never reorders or removes", () => {
  const existing = [
    { name: "keyboard-de", layout: "" },
    { name: "chewing", layout: "" },
    { name: "keyboard-us", layout: "us" }
  ]
  const merged = C.mergeGroup(existing, ["keyboard-us", "unikey", "chewing", "mozc"])
  assert.deepEqual(merged.slice(0, existing.length), existing)
  assert.deepEqual(merged.map(i => i.name), ["keyboard-de", "chewing", "keyboard-us", "unikey", "mozc"])
  // A keyboard layout already counts as English: no second one is added.
  assert.deepEqual(C.mergeGroup(group("keyboard-de"), ["keyboard-us"]).map(i => i.name), ["keyboard-de"])
  // Idempotent and doesn't mutate its input.
  assert.deepEqual(C.mergeGroup(merged, ["unikey", "mozc"]), merged)
  assert.equal(existing.length, 3)
  assert.deepEqual(C.mergeGroup([], ["keyboard-us", "unikey"]).map(i => i.name), ["keyboard-us", "unikey"])
})

test("removing a language drops only its engines and keeps keyboards", () => {
  const items = group("keyboard-us", "unikey", "mozc", "anthy")
  assert.deepEqual(C.removeFromGroup(items, ["mozc", "anthy"]).map(i => i.name), ["keyboard-us", "unikey"])
  assert.deepEqual(C.removeFromGroup(items, ["keyboard-us"]).map(i => i.name), ["keyboard-us", "unikey", "mozc", "anthy"])
})

test("languages in group: English first, engines grouped per language", () => {
  const langs = C.languagesInGroup(group("unikey", "keyboard-us", "pinyin", "shuangpin", "m17n_hi_inscript"))
  assert.deepEqual(langs.map(l => l.id), ["en", "vi", "zh-Hans", "m17n-hi"])
  assert.deepEqual(langs[2].engines, ["pinyin", "shuangpin"])
  assert.deepEqual(C.languagesInGroup([])[0].engines, ["keyboard-us"])
})

test("Ctrl+Shift / right click toggles English <-> last non-English language", () => {
  const engines = ["keyboard-us", "unikey", "mozc", "hangul"]
  // From English, back to the most recent non-English engine.
  assert.equal(C.toggleTarget("keyboard-us", ["unikey", "mozc"], engines), "mozc")
  // From any non-English engine, to the group's English layout.
  assert.equal(C.toggleTarget("mozc", ["unikey", "mozc"], engines), "keyboard-us")
  assert.equal(C.toggleTarget("hangul", [], ["keyboard-de", "hangul"]), "keyboard-de")
  // No history yet: the first non-English engine in the group.
  assert.equal(C.toggleTarget("keyboard-us", [], engines), "unikey")
  // History entries that left the group are skipped.
  assert.equal(C.toggleTarget("keyboard-us", ["hangul", "chewing"], engines), "hangul")
  // Only English: nothing to switch to.
  assert.equal(C.toggleTarget("keyboard-us", ["unikey"], ["keyboard-us"]), "")
})

test("history keeps non-English engines, most recent last, without duplicates", () => {
  let h = []
  for (const e of ["unikey", "keyboard-us", "mozc", "unikey", "keyboard-us"]) h = C.rememberEngine(h, e)
  assert.deepEqual(h, ["mozc", "unikey"])
  assert.equal(C.lastNonEnglish(h, ["keyboard-us", "unikey", "mozc"]), "unikey")
})

test("parses busctl group info and omakey-state output", () => {
  const info = 'sa(ss) "us" 3 "keyboard-us" "" "unikey" "" "mozc" "jp"'
  assert.deepEqual(C.parseGroupInfo(info), {
    layout: "us",
    items: [{ name: "keyboard-us", layout: "" }, { name: "unikey", layout: "" }, { name: "mozc", layout: "jp" }]
  })
  const state = C.parseState("im=unikey\ngroup=Default\ninfo=" + info + "\n")
  assert.equal(state.running, true)
  assert.equal(state.current, "unikey")
  assert.equal(state.group, "Default")
  assert.equal(state.items.length, 3)
  assert.equal(C.parseState("im=\n").running, false)
  assert.deepEqual(C.parseUnikeyConfig('a{sv} 2 "InputMethod" s "VNI" "SpellCheck" s "True" "UnikeyConfig" "x" s "y"'),
    { InputMethod: "VNI", SpellCheck: "True" })
})

test("bin/omakey-setup's catalogue copy matches Catalogue.mjs", () => {
  const script = readFileSync(new URL("../bin/omakey-setup", import.meta.url), "utf8")
  const block = script.split("# catalogue:start")[1].split("# catalogue:end")[0]
  const rows = block.split("\n").map(l => l.trim().split(/\s+/)).filter(r => r.length === 4)
  const expected = C.LANGUAGES.map(l => [l.id, l.badge, l.package || "-", l.engines[0]])
    .concat(C.LAYOUT_LANGUAGES.map(l => [l.id, l.badge, l.package || "-", l.engines[0]]))
    .concat([[C.OTHER.id, "-", C.OTHER.package, "-"]])
  assert.deepEqual(rows, expected)
})
