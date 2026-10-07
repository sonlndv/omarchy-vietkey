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
  assert.equal(C.badgeFor("bamboo"), "VI")
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
  const existing = group("keyboard-us", "bamboo")
  const merged = C.mergeGroup(existing, ["keyboard-ara", "keyboard-ru"])
  assert.deepEqual(merged.map(i => i.name), ["keyboard-us", "bamboo", "keyboard-ara", "keyboard-ru"])
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
    vi: ["fcitx5-bamboo", "bamboo"],
    ja: ["fcitx5-mozc", "mozc"],
    ko: ["fcitx5-hangul", "hangul"],
    "zh-Hans": ["fcitx5-chinese-addons", "pinyin"],
    "zh-Hant": ["fcitx5-chewing", "chewing"],
    th: ["fcitx5-libthai", "libthai"]
  })
  assert.equal(C.OTHER.package, "fcitx5-m17n")
})

test("badge mode: Telex/VNI for Bamboo and Unikey, input style for Chinese, none for English", () => {
  assert.equal(C.badgeMode("bamboo", { InputMethod: "VNI" }), "VNI")
  assert.equal(C.badgeMode("bamboo", {}), "Telex")
  assert.equal(C.badgeMode("bamboo"), "Telex")
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
  assert.deepEqual(C.packagesFor(["en", "vi", "ja"], ["fcitx5-bamboo"]), ["fcitx5-mozc"])
  assert.deepEqual(C.packagesFor(["en"], []), [])
  assert.deepEqual(C.enginesFor(["en", "vi", "other"]), ["keyboard-us", "bamboo"])
})

test("group merge appends missing engines and never reorders or removes", () => {
  const existing = [
    { name: "keyboard-de", layout: "" },
    { name: "chewing", layout: "" },
    { name: "keyboard-us", layout: "us" }
  ]
  const merged = C.mergeGroup(existing, ["keyboard-us", "bamboo", "chewing", "mozc"])
  assert.deepEqual(merged.slice(0, existing.length), existing)
  assert.deepEqual(merged.map(i => i.name), ["keyboard-de", "chewing", "keyboard-us", "bamboo", "mozc"])
  // A keyboard layout already counts as English: no second one is added.
  assert.deepEqual(C.mergeGroup(group("keyboard-de"), ["keyboard-us"]).map(i => i.name), ["keyboard-de"])
  // Idempotent and doesn't mutate its input.
  assert.deepEqual(C.mergeGroup(merged, ["bamboo", "mozc"]), merged)
  assert.equal(existing.length, 3)
  assert.deepEqual(C.mergeGroup([], ["keyboard-us", "bamboo"]).map(i => i.name), ["keyboard-us", "bamboo"])
})

test("removing a language drops only its engines and keeps keyboards", () => {
  const items = group("keyboard-us", "bamboo", "mozc", "anthy")
  assert.deepEqual(C.removeFromGroup(items, ["mozc", "anthy"]).map(i => i.name), ["keyboard-us", "bamboo"])
  assert.deepEqual(C.removeFromGroup(items, ["keyboard-us"]).map(i => i.name), ["keyboard-us", "bamboo", "mozc", "anthy"])
})

test("languages in group: English first, engines grouped per language", () => {
  const langs = C.languagesInGroup(group("bamboo", "keyboard-us", "pinyin", "shuangpin", "m17n_hi_inscript"))
  assert.deepEqual(langs.map(l => l.id), ["en", "vi", "zh-Hans", "m17n-hi"])
  assert.deepEqual(langs[2].engines, ["pinyin", "shuangpin"])
  assert.deepEqual(C.languagesInGroup([])[0].engines, ["keyboard-us"])
})

test("Ctrl+Shift / right click with only English: nothing to cycle to", () => {
  assert.equal(C.cycleTarget("keyboard-us", ["keyboard-us"]), "")
  assert.equal(C.cycleTarget("keyboard-de", ["keyboard-de"]), "")
  assert.equal(C.cycleTarget("", []), "")
})

test("Ctrl+Shift / right click with two languages flips between them", () => {
  const engines = ["keyboard-us", "bamboo"]
  assert.equal(C.cycleTarget("keyboard-us", engines), "bamboo")
  assert.equal(C.cycleTarget("bamboo", engines), "keyboard-us")
  // The group's own English layout, wherever it sits in the group.
  assert.equal(C.cycleTarget("hangul", ["hangul", "keyboard-de"]), "keyboard-de")
  assert.equal(C.cycleTarget("keyboard-de", ["hangul", "keyboard-de"]), "hangul")
})

test("Ctrl+Shift / right click with 3+ languages cycles in group order and wraps to English", () => {
  const engines = ["keyboard-us", "bamboo", "mozc", "hangul"]
  let engine = "keyboard-us"
  const seen = []
  for (let i = 0; i < 5; i++) {
    engine = C.cycleTarget(engine, engines)
    seen.push(engine)
  }
  assert.deepEqual(seen, ["bamboo", "mozc", "hangul", "keyboard-us", "bamboo"])
  // Another engine of the same language counts as that language; the next
  // language is entered on its first engine.
  const ja = ["keyboard-us", "mozc", "anthy", "pinyin", "shuangpin"]
  assert.equal(C.cycleTarget("anthy", ja), "pinyin")
  assert.equal(C.cycleTarget("shuangpin", ja), "keyboard-us")
  // Layout languages are languages of their own, not English.
  assert.equal(C.cycleTarget("keyboard-us", ["keyboard-us", "keyboard-ru", "bamboo"]), "keyboard-ru")
  assert.equal(C.cycleTarget("keyboard-ru", ["keyboard-us", "keyboard-ru", "bamboo"]), "bamboo")
  // An engine that left the group restarts the cycle after English.
  assert.equal(C.cycleTarget("chewing", engines), "bamboo")
})

test("cycle hint spells out the order with badges", () => {
  const langs = names => C.languagesInGroup(group(...names))
  assert.equal(C.cycleHint(langs(["keyboard-us"])), "Ctrl+Shift cycles languages")
  assert.equal(C.cycleHint(langs(["keyboard-us", "bamboo"])), "Ctrl+Shift: EN ↔ VI")
  assert.equal(C.cycleHint(langs(["keyboard-us", "bamboo", "mozc"])), "Ctrl+Shift cycles: EN → VI → JA → EN")
})

test("cycle hint names the switch key keymarchy-setup recorded", () => {
  const langs = names => C.languagesInGroup(group(...names))
  assert.equal(C.keyLabel(""), "Ctrl+Shift")
  assert.equal(C.keyLabel("CTRL + SHIFT"), "Ctrl+Shift")
  assert.equal(C.keyLabel("ALT + Z"), "Alt+Z")
  assert.equal(C.keyLabel("SUPER + space"), "Super+Space")
  assert.equal(C.cycleHint(langs(["keyboard-us", "bamboo"]), "ALT + Z"), "Alt+Z: EN ↔ VI")
  assert.equal(C.parseState("im=bamboo\nkey=ALT + Z\n").key, "ALT + Z")
  assert.equal(C.parseState("im=bamboo\n").key, "")
})

test("dashboard reorder moves languages, keeps English slots and engine order", () => {
  const items = group("keyboard-us", "bamboo", "mozc", "anthy", "hangul")
  const down = C.moveLanguage(items, "vi", 1)
  assert.deepEqual(down.map(i => i.name), ["keyboard-us", "mozc", "anthy", "bamboo", "hangul"])
  assert.deepEqual(C.languagesInGroup(down).map(l => l.id), ["en", "ja", "vi", "ko"])
  const up = C.moveLanguage(items, "ko", -1)
  assert.deepEqual(up.map(i => i.name), ["keyboard-us", "bamboo", "hangul", "mozc", "anthy"])
  // Edges and English don't move; nothing is dropped.
  assert.deepEqual(C.moveLanguage(items, "vi", -1), items)
  assert.deepEqual(C.moveLanguage(items, "ko", 1), items)
  assert.deepEqual(C.moveLanguage(items, "en", 1), items)
  // An English layout in the middle of the group keeps its slot.
  const mixed = [{ name: "bamboo", layout: "" }, { name: "keyboard-de", layout: "de" }, { name: "mozc", layout: "" }]
  assert.deepEqual(C.moveLanguage(mixed, "ja", -1),
    [{ name: "mozc", layout: "" }, { name: "keyboard-de", layout: "de" }, { name: "bamboo", layout: "" }])
  // The new order is the cycle order.
  const engines = up.map(i => i.name)
  assert.equal(C.cycleTarget("bamboo", engines), "hangul")
  assert.equal(C.cycleTarget("hangul", engines), "mozc")
})

test("group write arguments match keymarchy-setup's SetInputMethodGroupInfo call", () => {
  assert.deepEqual(C.setGroupArgs("Default", "us", [{ name: "keyboard-us", layout: "" }, { name: "mozc", layout: "jp" }]),
    ["SetInputMethodGroupInfo", "ssa(ss)", "Default", "us", "2", "keyboard-us", "", "mozc", "jp"])
})

test("parses busctl group info and keymarchy-state output", () => {
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
  assert.deepEqual(C.parseEngineConfig('a{sv} 2 "InputMethod" s "VNI" "SpellCheck" s "True" "UnikeyConfig" "x" s "y"'),
    { InputMethod: "VNI", SpellCheck: "True" })
  // Bamboo's GetConfig reply (fcitx5-bamboo 1.0.11): schema follows "BambooConfig".
  assert.deepEqual(C.parseEngineConfig('va(sa(sssva{sv})) a{sv} 2 "InputMethod" s "Telex" "OutputCharset" s "Unicode" 1 "BambooConfig" 11 "InputMethod" "String" "Input Method" s "VIQR"'),
    { InputMethod: "Telex", OutputCharset: "Unicode" })
})

test("Unikey from 2.0.x stays a Vietnamese engine next to Bamboo", () => {
  assert.equal(C.badgeFor("bamboo"), "VI")
  assert.equal(C.badgeFor("unikey"), "VI")
  assert.equal(C.languageForEngine("unikey").id, "vi")
  assert.equal(C.engineLabel("bamboo"), "Bamboo")
  // New setups add Bamboo; a group that already has Unikey is one VI language.
  assert.deepEqual(C.enginesFor(["en", "vi"]), ["keyboard-us", "bamboo"])
  const langs = C.languagesInGroup(group("keyboard-us", "unikey", "mozc"))
  assert.deepEqual(langs.map(l => l.id), ["en", "vi", "ja"])
  assert.deepEqual(langs[1].engines, ["unikey"])
  assert.equal(C.cycleTarget("unikey", ["keyboard-us", "unikey"]), "keyboard-us")
  assert.equal(C.cycleTarget("keyboard-us", ["keyboard-us", "unikey"]), "unikey")
})

test("Telex/VNI and options target the Vietnamese engine actually in the group", () => {
  assert.equal(C.vietnameseEngine(["keyboard-us", "bamboo"], "keyboard-us"), "bamboo")
  assert.equal(C.vietnameseEngine(["keyboard-us", "unikey"], "keyboard-us"), "unikey")
  assert.equal(C.vietnameseEngine(["keyboard-us", "unikey", "bamboo"], "bamboo"), "bamboo")
  assert.equal(C.vietnameseEngine(["keyboard-us", "unikey", "bamboo"], "keyboard-us"), "unikey")
  assert.equal(C.vietnameseEngine([], ""), "bamboo")
  assert.equal(C.configUriFor("bamboo"), "fcitx://config/inputmethod/bamboo")
  assert.equal(C.configUriFor("unikey"), "fcitx://config/inputmethod/unikey")
  // Charset values are what each engine's SetConfig accepts.
  assert.ok(C.vietnameseCharsets("bamboo").includes("TCVN3 (ABC)"))
  assert.ok(C.vietnameseCharsets("unikey").includes("TCVN3"))
  assert.equal(C.vietnameseCharsets("bamboo")[0], "Unicode")
  assert.ok(!C.vietnameseOptions("bamboo").includes("ProcessWAtBegin"))
  assert.ok(C.vietnameseOptions("unikey").includes("ProcessWAtBegin"))
})

test("bin/keymarchy-setup's catalogue copy matches Catalogue.mjs", () => {
  const script = readFileSync(new URL("../bin/keymarchy-setup", import.meta.url), "utf8")
  const block = script.split("# catalogue:start")[1].split("# catalogue:end")[0]
  const rows = block.split("\n").map(l => l.trim().split(/\s+/)).filter(r => r.length === 4)
  const expected = C.LANGUAGES.map(l => [l.id, l.badge, l.package || "-", l.engines[0]])
    .concat(C.LAYOUT_LANGUAGES.map(l => [l.id, l.badge, l.package || "-", l.engines[0]]))
    .concat([[C.OTHER.id, "-", C.OTHER.package, "-"]])
  assert.deepEqual(rows, expected)
})
