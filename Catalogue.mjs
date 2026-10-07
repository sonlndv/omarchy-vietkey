// Keymarchy language catalogue and the pure logic around it: badge codes, the
// first-run selection, fcitx5 group merges and reorders, and the Ctrl+Shift
// cycle. No Qt imports, so BarWidget.qml and `node --test` share this file.
//
// bin/keymarchy-setup keeps a copy of the id/badge/package/engine columns
// between `# catalogue:start` and `# catalogue:end`; test/catalogue.test.mjs
// fails if the two drift apart.

export const ENGLISH = "en"
export const VIETNAMESE = "vi"
export const M17N_PACKAGE = "fcitx5-m17n"

// `engines` lists the engine Keymarchy adds first, then other engines that count
// as the same language when they are already in the user's fcitx5 group.
// `modes` are informational for engines Keymarchy can't switch modes on.
export const LANGUAGES = [
  { id: "en", badge: "EN", name: "English", nativeName: "English",
    package: "", engines: ["keyboard-us"], modes: [] },
  { id: "vi", badge: "VI", name: "Vietnamese", nativeName: "Tiếng Việt",
    package: "fcitx5-bamboo", engines: ["bamboo", "unikey"], modes: ["Telex", "VNI"] },
  { id: "ja", badge: "JA", name: "Japanese", nativeName: "日本語",
    package: "fcitx5-mozc", engines: ["mozc", "anthy", "skk", "kkc"],
    modes: ["Hiragana", "Katakana", "Half-width Katakana", "Direct input"] },
  { id: "ko", badge: "KO", name: "Korean", nativeName: "한국어",
    package: "fcitx5-hangul", engines: ["hangul"], modes: [] },
  { id: "zh-Hans", badge: "ZH", name: "Chinese Simplified", nativeName: "简体中文",
    package: "fcitx5-chinese-addons", engines: ["pinyin", "shuangpin", "wbx"], modes: [] },
  { id: "zh-Hant", badge: "ZH", name: "Chinese Traditional", nativeName: "繁體中文",
    package: "fcitx5-chewing", engines: ["chewing"], modes: [] },
  { id: "th", badge: "TH", name: "Thai", nativeName: "ไทย",
    package: "fcitx5-libthai", engines: ["libthai"], modes: [] }
]

// Anything else goes through fcitx5-m17n; the engine is picked from fcitx5's
// own list by keymarchy-setup.
export const OTHER = {
  id: "other", badge: "", name: "Other language (m17n)", nativeName: "",
  package: M17N_PACKAGE, engines: [], modes: []
}

// LAYOUT languages: an XKB layout fcitx5 already understands as its own
// "keyboard-<xkb>" engine. No package to install, nothing to restart fcitx5
// for — the layout just needs appending to the group. `xkbCode` is the rules
// file code from /usr/share/X11/xkb/rules/base.lst; `engines[0]` is always
// "keyboard-" + xkbCode. Hindi's variant may need to be more specific than
// the bare "in" layout (its base.lst default is Devanagari) — flagged for
// Jarvis/Son to confirm on real hardware; keeping bare "in" for v1.
export const LAYOUT_LANGUAGES = [
  { id: "ar-kbd", badge: "AR", name: "Arabic", nativeName: "العربية",
    package: "", engines: ["keyboard-ara"], modes: [], xkbCode: "ara" },
  { id: "fa-kbd", badge: "FA", name: "Persian", nativeName: "فارسی",
    package: "", engines: ["keyboard-ir"], modes: [], xkbCode: "ir" },
  { id: "he-kbd", badge: "HE", name: "Hebrew", nativeName: "עברית",
    package: "", engines: ["keyboard-il"], modes: [], xkbCode: "il" },
  { id: "ru-kbd", badge: "RU", name: "Russian", nativeName: "Русский",
    package: "", engines: ["keyboard-ru"], modes: [], xkbCode: "ru" },
  { id: "uk-kbd", badge: "UK", name: "Ukrainian", nativeName: "Українська",
    package: "", engines: ["keyboard-ua"], modes: [], xkbCode: "ua" },
  { id: "el-kbd", badge: "EL", name: "Greek", nativeName: "Ελληνικά",
    package: "", engines: ["keyboard-gr"], modes: [], xkbCode: "gr" },
  { id: "hi-kbd", badge: "HI", name: "Hindi", nativeName: "हिन्दी",
    package: "", engines: ["keyboard-in"], modes: [], xkbCode: "in" },
  // Alternative to fcitx5-libthai when that package isn't wanted: the bare
  // Thai XKB layout. Distinct id from the "th" (libthai) LANGUAGES entry —
  // same badge is fine, the picker shows both with different labels.
  { id: "th-kbd", badge: "TH", name: "Thai (keyboard layout)", nativeName: "ไทย",
    package: "", engines: ["keyboard-th"], modes: [], xkbCode: "th" }
]

// The picker's catch-all: any other XKB layout from base.lst. No fixed
// engine; keymarchy-setup resolves "keyboard-<code>" from the code the user
// picks and appends it like any other LAYOUT language.
export const OTHER_LAYOUT = {
  id: "other-layout", badge: "", name: "Other keyboard layout…", nativeName: "",
  package: "", engines: [], modes: []
}

const ENGINE_LABELS = {
  bamboo: "Bamboo", unikey: "Unikey", mozc: "Mozc", anthy: "Anthy", skk: "SKK", kkc: "KKC",
  hangul: "Hangul", pinyin: "Pinyin", shuangpin: "Shuangpin", wbx: "Wubi",
  chewing: "Zhuyin", libthai: "Thai"
}

export function byId(id) {
  if (id === OTHER.id) return OTHER
  if (id === OTHER_LAYOUT.id) return OTHER_LAYOUT
  for (const language of LANGUAGES)
    if (language.id === id) return language
  for (const language of LAYOUT_LANGUAGES)
    if (language.id === id) return language
  return null
}

// Only "keyboard-us" and the user's own base layout (any keyboard-<code>
// Keymarchy didn't add as a LAYOUT language) count as English. A LAYOUT
// language's own engine — keyboard-ara, keyboard-ru, keyboard-il, … —
// never does, even though it's still a "keyboard-*" engine name.
export function isEnglishEngine(engine) {
  if (typeof engine !== "string" || engine.indexOf("keyboard-") !== 0) return false
  const code = engine.slice("keyboard-".length)
  return !LAYOUT_LANGUAGES.some(language => language.xkbCode === code)
}

export function engineLabel(engine) {
  if (ENGINE_LABELS[engine]) return ENGINE_LABELS[engine]
  const m17n = /^m17n_([^_]+)_(.+)$/.exec(engine || "")
  if (m17n) return m17n[2]
  return engine || ""
}

// Catalogue entry for an engine name; m17n and unknown engines get an entry
// made up from the name so the menu can still show them.
export function languageForEngine(engine) {
  if (!engine || isEnglishEngine(engine)) return LANGUAGES[0]
  for (const language of LANGUAGES)
    if (language.engines.indexOf(engine) >= 0) return language
  for (const language of LAYOUT_LANGUAGES)
    if (language.engines.indexOf(engine) >= 0) return language
  const m17n = /^m17n_([^_]+)_/.exec(engine)
  const code = m17n ? m17n[1] : engine
  return {
    id: m17n ? "m17n-" + code : engine,
    badge: code.slice(0, 2).toUpperCase(),
    name: m17n ? code + " (" + m17n[0].slice(0, -1) + ")" : engine,
    nativeName: "",
    package: m17n ? M17N_PACKAGE : "",
    engines: [engine],
    modes: []
  }
}

export function badgeFor(engine) {
  return languageForEngine(engine).badge
}

// Vietnamese engines Keymarchy drives (Telex/VNI over D-Bus). Bamboo is the
// one keymarchy-setup installs; Unikey (Keymarchy 2.0.x) keeps working where
// it is already in the group.
export const VIETNAMESE_ENGINES = ["bamboo", "unikey"]

export function isVietnameseEngine(engine) {
  return VIETNAMESE_ENGINES.indexOf(engine) >= 0
}

// The engine Telex/VNI switching and the Vietnamese options apply to: the
// current engine if it is Vietnamese, else the first Vietnamese engine in
// the group, else Bamboo (what keymarchy-setup adds).
export function vietnameseEngine(engines, current) {
  if (isVietnameseEngine(current)) return current
  for (const engine of engines || [])
    if (isVietnameseEngine(engine)) return engine
  return VIETNAMESE_ENGINES[0]
}

// fcitx5's config URI for an input method's options; Bamboo and Unikey both
// answer on fcitx://config/inputmethod/<engine>.
export function configUriFor(engine) {
  return "fcitx://config/inputmethod/" + engine
}

// Output charsets and boolean options as each engine spells them in its
// config (Bamboo and Unikey name the same charsets differently, and only
// Unikey has ProcessWAtBegin). Values are what SetConfig must be sent.
const VIETNAMESE_CHARSETS = {
  bamboo: ["Unicode", "TCVN3 (ABC)", "VNI Windows", "VIQR", "BKHCM 2", "Unicode C string Hex", "NCR Decimal", "NCR Hex"],
  unikey: ["Unicode", "TCVN3", "VNI Win", "VIQR", "BK HCM 2", "CString", "NCR Decimal", "NCR Hex"]
}
const VIETNAMESE_OPTIONS = {
  bamboo: ["SpellCheck", "AutoNonVnRestore", "ModernStyle", "FreeMarking"],
  unikey: ["SpellCheck", "AutoNonVnRestore", "ModernStyle", "FreeMarking", "ProcessWAtBegin"]
}

export function vietnameseCharsets(engine) {
  return VIETNAMESE_CHARSETS[engine] || VIETNAMESE_CHARSETS.bamboo
}

export function vietnameseOptions(engine) {
  return VIETNAMESE_OPTIONS[engine] || VIETNAMESE_OPTIONS.bamboo
}

// Text next to the badge: Telex/VNI for the Vietnamese engine (read from its
// config), and the input style for Chinese, where ZH alone is ambiguous.
export function badgeMode(engine, viConfig) {
  if (isVietnameseEngine(engine)) return (viConfig && viConfig.InputMethod) || "Telex"
  const language = languageForEngine(engine)
  if (language.id === "zh-Hans" || language.id === "zh-Hant") return engineLabel(engine)
  return ""
}

// ------------------------------------------------------------ selection

// First run: English always, Vietnamese pre-ticked, everything else opt-in.
export function defaultSelection() {
  return [ENGLISH, VIETNAMESE]
}

// English first and always present; unknown ids dropped; no duplicates.
export function normalizeSelection(ids) {
  const out = [ENGLISH]
  for (const id of ids || [])
    if (id !== ENGLISH && byId(id) && out.indexOf(id) < 0) out.push(id)
  return out
}

// English can't be unticked.
export function toggleSelection(ids, id) {
  const current = normalizeSelection(ids)
  if (id === ENGLISH || !byId(id)) return current
  const at = current.indexOf(id)
  if (at >= 0) return current.filter(other => other !== id)
  return normalizeSelection(current.concat([id]))
}

// The picker's starting ticks: the first-run default while the group holds
// only English, else the catalogue languages already in the group.
export function initialSelection(items) {
  const ids = languagesInGroup(items).map(language => language.id).filter(id => byId(id))
  return ids.length > 1 ? normalizeSelection(ids) : defaultSelection()
}

export function packagesFor(ids, installed) {
  const have = installed || []
  const out = []
  for (const id of normalizeSelection(ids)) {
    const pkg = byId(id).package
    if (pkg && have.indexOf(pkg) < 0 && out.indexOf(pkg) < 0) out.push(pkg)
  }
  return out
}

// The engine each language adds. `other` has none: it's chosen later from
// fcitx5's m17n list.
export function enginesFor(ids) {
  const out = []
  for (const id of normalizeSelection(ids)) {
    const language = byId(id)
    if (language.engines.length > 0) out.push(language.engines[0])
  }
  return out
}

// ---------------------------------------------------------------- group

// Group items are { name, layout } in fcitx5's order. Existing items are kept
// exactly, in place; only engines not yet present are appended.
export function mergeGroup(items, engines) {
  const out = (items || []).map(item => ({ name: item.name, layout: item.layout || "" }))
  for (const engine of engines || []) {
    if (!engine) continue
    if (out.some(item => item.name === engine)) continue
    if (isEnglishEngine(engine) && out.some(item => isEnglishEngine(item.name))) continue
    out.push({ name: engine, layout: "" })
  }
  return out
}

// Drops the given engines and nothing else; keyboard layouts always stay.
export function removeFromGroup(items, engines) {
  return (items || []).filter(item => isEnglishEngine(item.name) || (engines || []).indexOf(item.name) < 0)
    .map(item => ({ name: item.name, layout: item.layout || "" }))
}

// One entry per language in group order, English first, each with the
// group's engines for it.
export function languagesInGroup(items) {
  const english = Object.assign({}, LANGUAGES[0], { engines: [] })
  const out = [english]
  for (const item of items || []) {
    const language = languageForEngine(item.name)
    if (language.id === ENGLISH) { english.engines.push(item.name); continue }
    let entry = out.find(other => other.id === language.id)
    if (!entry) {
      entry = Object.assign({}, language, { engines: [] })
      out.push(entry)
    }
    entry.engines.push(item.name)
  }
  if (english.engines.length === 0) english.engines.push(LANGUAGES[0].engines[0])
  return out
}

// The group's languages, in the order the settings dashboard can change:
// English stays first, the rest move one step up (-1) or down (+1). Only the
// non-English items trade places; English items keep their slots in the
// group, and each language's engines keep their relative order. Returns the
// new group items, or a copy of the old ones when nothing can move.
export function moveLanguage(items, id, delta) {
  const ids = languagesInGroup(items).slice(1).map(language => language.id)
  const at = ids.indexOf(id)
  const to = at + delta
  if (at < 0 || to < 0 || to >= ids.length) return reorderGroup(items, ids)
  ids.splice(at, 1)
  ids.splice(to, 0, id)
  return reorderGroup(items, ids)
}

// Group items with the non-English ones sorted into the given language
// order; English items and languages not listed stay where they are.
export function reorderGroup(items, ids) {
  const list = (items || []).map(item => ({ name: item.name, layout: item.layout || "" }))
  const rank = item => {
    const at = (ids || []).indexOf(languageForEngine(item.name).id)
    return at < 0 ? (ids || []).length : at
  }
  const others = list.map((item, n) => ({ item, n })).filter(entry => !isEnglishEngine(entry.item.name))
  const sorted = others.slice().sort((a, b) => rank(a.item) - rank(b.item) || a.n - b.n)
  const out = list.slice()
  others.forEach((entry, k) => { out[entry.n] = sorted[k].item })
  return out
}

// busctl arguments after the Controller1 interface for writing a group, the
// same call bin/keymarchy-setup's write_group makes.
export function setGroupArgs(group, layout, items) {
  const args = ["SetInputMethodGroupInfo", "ssa(ss)", group, layout || "", String((items || []).length)]
  for (const item of items || []) args.push(item.name, item.layout || "")
  return args
}

// ---------------------------------------------------------------- cycle

// Ctrl+Shift / right click: the next language in group order (English
// first), wrapping back to English after the last one. Lands on the
// language's first engine. Returns "" with only English in the group.
export function cycleTarget(currentEngine, groupEngines) {
  const languages = languagesInGroup((groupEngines || []).map(name => ({ name, layout: "" })))
  if (languages.length < 2) return ""
  const id = languageForEngine(currentEngine).id
  const at = Math.max(0, languages.findIndex(language => language.id === id))
  return languages[(at + 1) % languages.length].engines[0]
}

// The switch key as people say it: "ALT + Z" -> "Alt+Z", "SUPER + space" ->
// "Super+Space". Empty (an older block without -- keymarchy:key=) is the
// Ctrl+Shift default.
export function keyLabel(key) {
  const parts = String(key || "").split("+").map(part => part.trim()).filter(Boolean)
  if (parts.length === 0) return "Ctrl+Shift"
  return parts.map(part => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase()).join("+")
}

// The cycle spelled out with badges for menus and tooltips.
export function cycleHint(languages, key) {
  const label = keyLabel(key)
  const badges = (languages || []).map(language => language.badge || language.name)
  if (badges.length < 2) return label + " cycles languages"
  if (badges.length === 2) return label + ": " + badges[0] + " ↔ " + badges[1]
  return label + " cycles: " + badges.concat([badges[0]]).join(" → ")
}

// -------------------------------------------------------------- parsing

function busctlTokens(text) {
  const out = []
  const re = /"((?:[^"\\]|\\.)*)"|(\S+)/g
  let m
  while ((m = re.exec(text || "")) !== null) out.push(m[1] !== undefined ? m[1] : m[2])
  return out
}

// `busctl call ... InputMethodGroupInfo` prints:
//   sa(ss) "us" 2 "keyboard-us" "" "unikey" ""
export function parseGroupInfo(text) {
  const tokens = busctlTokens(text)
  if (tokens[0] !== "sa(ss)") return { layout: "", items: [] }
  const count = Number(tokens[2]) || 0
  const items = []
  for (let i = 0; i < count; i++) {
    const name = tokens[3 + i * 2]
    if (name === undefined) break
    items.push({ name: name, layout: tokens[4 + i * 2] || "" })
  }
  return { layout: tokens[1] || "", items: items }
}

// bin/keymarchy-state prints `im=`, `group=`, `info=` and `key=` lines.
export function parseState(text) {
  const state = { running: false, current: "", group: "", layout: "", items: [], key: "" }
  for (const line of String(text || "").split("\n")) {
    const at = line.indexOf("=")
    if (at < 0) continue
    const key = line.slice(0, at)
    const value = line.slice(at + 1).trim()
    if (key === "im") state.current = value
    else if (key === "group") state.group = value
    else if (key === "key") state.key = value
    else if (key === "info") {
      const info = parseGroupInfo(value)
      state.layout = info.layout
      state.items = info.items
    }
  }
  state.running = state.current !== ""
  return state
}

// `busctl call ... GetConfig s fcitx://config/inputmethod/<engine>`: values
// come first, the option schema follows from "BambooConfig" / "UnikeyConfig".
export function parseEngineConfig(text) {
  const values = String(text || "").split(/"[A-Za-z]+Config"/)[0]
  const out = {}
  const re = /"([A-Za-z]+)" s "([^"]*)"/g
  let m
  while ((m = re.exec(values)) !== null) out[m[1]] = m[2]
  return out
}
