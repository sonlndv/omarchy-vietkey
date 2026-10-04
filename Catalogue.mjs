// Omakey language catalogue and the pure logic around it: badge codes, the
// first-run selection, append-only fcitx5 group merges and the Ctrl+Shift
// toggle. No Qt imports, so BarWidget.qml and `node --test` share this file.
//
// bin/omakey-setup keeps a copy of the id/badge/package/engine columns
// between `# catalogue:start` and `# catalogue:end`; test/catalogue.test.mjs
// fails if the two drift apart.

export const ENGLISH = "en"
export const VIETNAMESE = "vi"
export const M17N_PACKAGE = "fcitx5-m17n"

// `engines` lists the engine Omakey adds first, then other engines that count
// as the same language when they are already in the user's fcitx5 group.
// `modes` are informational for engines Omakey can't switch modes on.
export const LANGUAGES = [
  { id: "en", badge: "EN", name: "English", nativeName: "English",
    package: "", engines: ["keyboard-us"], modes: [] },
  { id: "vi", badge: "VI", name: "Vietnamese", nativeName: "Tiếng Việt",
    package: "fcitx5-unikey", engines: ["unikey"], modes: ["Telex", "VNI"] },
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
// own list by omakey-setup.
export const OTHER = {
  id: "other", badge: "", name: "Other language (m17n)", nativeName: "",
  package: M17N_PACKAGE, engines: [], modes: []
}

const ENGINE_LABELS = {
  unikey: "Unikey", mozc: "Mozc", anthy: "Anthy", skk: "SKK", kkc: "KKC",
  hangul: "Hangul", pinyin: "Pinyin", shuangpin: "Shuangpin", wbx: "Wubi",
  chewing: "Zhuyin", libthai: "Thai"
}

export function byId(id) {
  if (id === OTHER.id) return OTHER
  for (const language of LANGUAGES)
    if (language.id === id) return language
  return null
}

export function isEnglishEngine(engine) {
  return typeof engine === "string" && engine.indexOf("keyboard-") === 0
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

// Text next to the badge: Telex/VNI for Unikey (read from its config), and
// the input style for Chinese, where ZH alone is ambiguous.
export function badgeMode(engine, unikeyConfig) {
  if (engine === "unikey") return (unikeyConfig && unikeyConfig.InputMethod) || "Telex"
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

// --------------------------------------------------------------- toggle

// History holds non-English engines, most recent last.
export function rememberEngine(history, engine) {
  const out = (history || []).filter(other => other !== engine)
  if (engine && !isEnglishEngine(engine)) out.push(engine)
  return out.slice(-8)
}

// The most recently used non-English engine still in the group, else the
// group's first non-English engine, else "".
export function lastNonEnglish(history, groupEngines) {
  const engines = groupEngines || []
  const past = history || []
  for (let i = past.length - 1; i >= 0; i--)
    if (!isEnglishEngine(past[i]) && engines.indexOf(past[i]) >= 0) return past[i]
  for (const engine of engines)
    if (!isEnglishEngine(engine)) return engine
  return ""
}

// Ctrl+Shift / right click: from any non-English engine to English, from
// English back to the last non-English one. Returns "" when there's nothing
// to switch to.
export function toggleTarget(currentEngine, history, groupEngines) {
  const engines = groupEngines || []
  if (currentEngine && !isEnglishEngine(currentEngine)) {
    for (const engine of engines)
      if (isEnglishEngine(engine)) return engine
    return LANGUAGES[0].engines[0]
  }
  return lastNonEnglish(history, engines)
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

// bin/omakey-state prints `im=`, `group=` and `info=` lines.
export function parseState(text) {
  const state = { running: false, current: "", group: "", layout: "", items: [] }
  for (const line of String(text || "").split("\n")) {
    const at = line.indexOf("=")
    if (at < 0) continue
    const key = line.slice(0, at)
    const value = line.slice(at + 1).trim()
    if (key === "im") state.current = value
    else if (key === "group") state.group = value
    else if (key === "info") {
      const info = parseGroupInfo(value)
      state.layout = info.layout
      state.items = info.items
    }
  }
  state.running = state.current !== ""
  return state
}

// `busctl call ... GetConfig s fcitx://config/inputmethod/unikey`: values
// come first, the option schema follows from "UnikeyConfig".
export function parseUnikeyConfig(text) {
  const values = String(text || "").split('"UnikeyConfig"')[0]
  const out = {}
  const re = /"([A-Za-z]+)" s "([^"]*)"/g
  let m
  while ((m = re.exec(values)) !== null) out[m[1]] = m[2]
  return out
}
