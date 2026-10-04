pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Catalogue.mjs" as Catalogue

// Omakey: input languages for fcitx5. English plus Vietnamese (Unikey, Telex
// or VNI) by default; Japanese, Korean, Chinese, Thai and m17n on request.
//
// The plugin id stays sonlndv.vietkey (moduleName, IPC target) so VietKey
// installs upgrade in place.
//
// State comes from bin/omakey-state (read-only: current engine + the fcitx5
// group). It is re-read when Omakey switches, on Hyprland focus changes and
// when the menu opens; a slow fallback timer only catches switches made
// outside Omakey (fcitx5's own hotkeys or config tool), which send no event.
//
// Left click opens the menu; right click and Ctrl+Shift (bound in Hyprland to
// the `toggle` IPC call) flip English <-> the last non-English language.
Panel {
  id: root
  moduleName: "sonlndv.vietkey"
  manageIpc: false

  readonly property string configUri: "fcitx://config/inputmethod/unikey"
  readonly property var busctl: ["busctl", "--user", "--auto-start=no", "call", "org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1"]
  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
  readonly property string setupPath: pluginDir + "/bin/omakey-setup"
  readonly property string statePath: pluginDir + "/bin/omakey-state"

  property bool running: true
  property string current: ""                 // fcitx5 engine name, e.g. "unikey"
  property var groupItems: []                 // [{ name, layout }] in fcitx5 order
  property var history: []                    // recent non-English engines, newest last
  readonly property var languages: Catalogue.languagesInGroup(groupItems)
  readonly property var groupEngines: groupItems.map(function(item) { return item.name })
  readonly property var currentLanguage: Catalogue.languageForEngine(current)
  readonly property bool english: currentLanguage.id === Catalogue.ENGLISH
  readonly property string lastEngine: Catalogue.lastNonEnglish(history, groupEngines)
  readonly property var lastLanguage: lastEngine ? Catalogue.languageForEngine(lastEngine) : null

  // Unikey's live options, e.g. { InputMethod: "Telex", SpellCheck: "True" }.
  property var config: ({ InputMethod: "Telex" })
  readonly property string viMode: config.InputMethod || "Telex"
  readonly property string modeText: Catalogue.badgeMode(current, config)

  property bool settingsOpen: false
  property string settingsLanguage: "vi"

  // "menu", "add" (also the first-run picker) or "remove".
  property string view: "menu"
  property var picks: []

  readonly property bool showModeName: setting("showModeName", true) !== false
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var rows: buildRows(view, languages, current, viMode, picks, lastLanguage, running)

  property int cursorIndex: 0
  // Hide the initial highlight until keyboard navigation or hover begins.
  property bool cursorActive: false

  function displayName(language) {
    if (!language) return ""
    return language.nativeName && language.nativeName !== language.name
      ? language.nativeName + " · " + language.name : language.name
  }

  // Menu rows in display order. Keyboard navigation skips separators, hints
  // and disabled rows.
  function buildRows(view, languages, current, viMode, picks, lastLanguage, running) {
    var out = []
    var enabledIds = languages.map(function(l) { return l.id })

    if (view === "add") {
      var firstRun = languages.length < 2
      out.push({ kind: "hint", label: firstRun ? "Choose your languages" : "Add languages" })
      var catalogue = Catalogue.LANGUAGES.concat([Catalogue.OTHER])
      for (var i = 0; i < catalogue.length; i++) {
        var entry = catalogue[i]
        var have = enabledIds.indexOf(entry.id) >= 0
        out.push({
          kind: "pick", langId: entry.id, glyph: entry.badge || "+",
          label: displayName(entry) + (entry.id === Catalogue.ENGLISH ? " (always on)" : have ? " (added)" : ""),
          checked: have || picks.indexOf(entry.id) >= 0,
          disabled: entry.id === Catalogue.ENGLISH || have
        })
      }
      var fresh = picks.filter(function(id) { return enabledIds.indexOf(id) < 0 })
      out.push({ kind: "separator" })
      out.push({ kind: "action", action: "install", icon: "󰏗", disabled: fresh.length === 0,
        label: fresh.length === 0 ? "Nothing new selected" : "Install and add (" + fresh.length + ")…" })
      out.push({ kind: "action", action: "back", icon: "󰁍", label: "Back" })
      return out
    }

    if (view === "remove") {
      out.push({ kind: "hint", label: "Remove from fcitx5 (packages stay installed)" })
      for (var r = 1; r < languages.length; r++)
        out.push({ kind: "action", action: "removeLanguage", glyph: languages[r].badge,
          label: displayName(languages[r]), engines: languages[r].engines })
      out.push({ kind: "separator" })
      out.push({ kind: "action", action: "back", icon: "󰁍", label: "Back" })
      return out
    }

    if (!running) out.push({ kind: "hint", label: "fcitx5 isn't running" })

    for (var j = 0; j < languages.length; j++) {
      var language = languages[j]
      var active = language.engines.indexOf(current) >= 0 || (j === 0 && Catalogue.isEnglishEngine(current))
      out.push({ kind: "source", glyph: language.badge, label: displayName(language), checked: active,
        engine: active ? current : language.engines[0] })
      if (language.id === Catalogue.VIETNAMESE) {
        for (var m = 0; m < language.modes.length; m++)
          out.push({ kind: "sub", mode: language.modes[m], label: language.modes[m],
            checked: current === "unikey" && viMode === language.modes[m] })
      } else if (language.engines.length > 1) {
        for (var e = 0; e < language.engines.length; e++)
          out.push({ kind: "sub", engine: language.engines[e], label: Catalogue.engineLabel(language.engines[e]),
            checked: current === language.engines[e] })
      }
    }

    out.push({ kind: "separator" })
    if (languages.length < 2) {
      out.push({ kind: "action", action: "add", icon: "󰌌", label: "Set up languages…" })
    } else {
      out.push({ kind: "action", action: "add", icon: "󰐕", label: "Add language…" })
      out.push({ kind: "action", action: "remove", icon: "󰍴", label: "Remove language…" })
      out.push({ kind: "action", action: "settings", icon: "󰒓", label: "Language settings…" })
    }
    out.push({ kind: "separator" })
    out.push({ kind: "hint", label: lastLanguage ? "Ctrl+Shift: English ↔ " + lastLanguage.name
      : "Ctrl+Shift switches language" })
    return out
  }

  function actionable(i) {
    if (i < 0 || i >= rows.length || rows[i].disabled) return false
    var kind = rows[i].kind
    return kind === "source" || kind === "sub" || kind === "action" || kind === "pick"
  }

  function moveCursor(delta) {
    var i = cursorIndex
    for (var step = 0; step < rows.length; step++) {
      i = (i + delta + rows.length) % rows.length
      if (actionable(i)) { cursorIndex = i; return }
    }
  }

  function resetCursor() {
    cursorIndex = 0
    for (var i = 0; i < rows.length; i++)
      if (actionable(i) && (rows[i].checked || view !== "menu")) { cursorIndex = i; return }
    if (!actionable(cursorIndex)) moveCursor(1)
  }

  function showView(next) {
    if (next === "add") picks = Catalogue.initialSelection(groupItems)
    view = next
    resetCursor()
  }

  function activate(row) {
    if (!row || row.disabled) return
    if (row.kind === "source") {
      switchTo(row.engine)
      close()
    } else if (row.kind === "sub") {
      if (row.mode) setMode(row.mode)
      else switchTo(row.engine)
      close()
    } else if (row.kind === "pick") {
      picks = Catalogue.toggleSelection(picks, row.langId)
    } else if (row.action === "add" || row.action === "remove") {
      showView(row.action)
    } else if (row.action === "back") {
      showView("menu")
    } else if (row.action === "install") {
      installPicks()
      close()
    } else if (row.action === "removeLanguage") {
      removeLanguage(row.engines)
      showView("menu")
    } else if (row.action === "settings") {
      close()
      openSettings("")
    }
  }

  // ------------------------------------------------------------- fcitx5

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  function refreshConfig() {
    if (!configProc.running) configProc.running = true
  }

  function switchTo(engine) {
    if (!engine) return
    current = engine
    history = Catalogue.rememberEngine(history, engine)
    run(["fcitx5-remote", "-s", engine])
  }

  // English <-> the last non-English language, keeping its mode. With only
  // English in the group there is nothing to switch to, so offer the picker.
  function toggle() {
    var target = Catalogue.toggleTarget(current, history, groupEngines)
    if (target) switchTo(target)
    else openPicker()
  }

  function setEnglish() {
    var keyboards = groupEngines.filter(Catalogue.isEnglishEngine)
    switchTo(keyboards.length > 0 ? keyboards[0] : Catalogue.LANGUAGES[0].engines[0])
  }

  // onOpenedChanged resets the view, so pick "add" after it has run.
  function openPicker() {
    open()
    Qt.callLater(function() { root.showView("add") })
  }

  function setLanguage(id) {
    for (var i = 0; i < languages.length; i++)
      if (languages[i].id === id) { switchTo(languages[i].engines[0]); return }
  }

  // Telex or VNI, landing in Vietnamese so it is usable straight away.
  function setMode(mode) {
    if (mode !== "Telex" && mode !== "VNI") return
    current = "unikey"
    history = Catalogue.rememberEngine(history, "unikey")
    setOption("InputMethod", mode, "fcitx5-remote -s unikey")
  }

  // Unikey stores every option, booleans included, as a string.
  function setOption(key, value, then) {
    var next = {}
    for (var k in config) next[k] = config[k]
    next[key] = String(value)
    config = next
    var cmd = root.busctl.map(Util.shellQuote).join(" ")
      + " SetConfig sv " + Util.shellQuote(configUri) + " 'a{sv}' 1 "
      + Util.shellQuote(key) + " s " + Util.shellQuote(String(value))
    run(["sh", "-c", then ? cmd + " && " + then : cmd])
  }

  // Installing may ask for a password and a fcitx5 restart, so it runs in
  // Omarchy's floating terminal; the badge catches up on the next focus event.
  function installPicks() {
    var enabledIds = languages.map(function(l) { return l.id })
    var fresh = picks.filter(function(id) { return enabledIds.indexOf(id) < 0 })
    if (fresh.length === 0) return
    Util.execArgv(["omarchy-launch-floating-terminal-with-presentation",
      "bash " + Util.shellQuote(setupPath) + " --add " + Util.shellQuote(fresh.join(","))])
  }

  // Only drops the engines from the fcitx5 group; packages stay installed.
  function removeLanguage(engines) {
    if (!engines || engines.length === 0) return
    if (engines.indexOf(current) >= 0) setEnglish()
    history = history.filter(function(engine) { return engines.indexOf(engine) < 0 })
    run(["bash", setupPath, "--remove", engines.join(",")])
  }

  // Settings for a language id; "" means the current language, or the last
  // non-English one while English is active.
  function openSettings(id) {
    var target = id || (!english ? currentLanguage.id : lastLanguage ? lastLanguage.id : "")
    var known = languages.some(function(l) { return l.id === target })
    settingsLanguage = known ? target : (languages.length > 1 ? languages[1].id : Catalogue.ENGLISH)
    refreshConfig()
    settingsOpen = true
  }

  function closeSettings() {
    settingsOpen = false
  }

  function openFcitxConfig() {
    Util.execArgv(["fcitx5-configtool"])
  }

  function run(command) {
    if (actionProc.running) {
      queued.push(command)
      return
    }
    actionProc.command = command
    actionProc.running = true
  }

  property var queued: []

  Component.onCompleted: {
    refresh()
    refreshConfig()
  }

  onOpenedChanged: {
    if (opened) {
      view = "menu"
      cursorActive = false
      resetCursor()
      refresh()
      refreshConfig()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    } else {
      view = "menu"
    }
  }

  Process {
    id: stateProc
    command: ["bash", root.statePath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var state = Catalogue.parseState(text)
        root.running = state.running
        if (!state.running) return
        root.current = state.current
        if (state.items.length > 0) root.groupItems = state.items
        root.history = Catalogue.rememberEngine(root.history, state.current)
      }
    }
  }

  Process {
    id: configProc
    command: root.busctl.concat(["GetConfig", "s", root.configUri])
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = Catalogue.parseUnikeyConfig(text)
        if (!next.InputMethod) return
        root.config = next
        if (next.InputMethod !== "Telex" && next.InputMethod !== "VNI") root.setOption("InputMethod", "Telex")
        else if (next.Macro === "True") root.setOption("Macro", "False")
      }
    }
  }

  Process {
    id: actionProc
    onRunningChanged: if (!running) {
      if (root.queued.length > 0) {
        command = root.queued.shift()
        running = true
        return
      }
      root.refresh()
      root.refreshConfig()
    }
  }

  // Focus changes are when a switch made elsewhere becomes visible; coalesce
  // bursts of Hyprland events into one read.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "activewindowv2") refreshDebounce.restart()
    }
  }

  Timer {
    id: refreshDebounce
    interval: 150
    onTriggered: root.refresh()
  }

  // Slow fallback for switches with no event (fcitx5's own hotkeys).
  Timer {
    interval: Math.max(2000, Number(root.setting("fallbackRefreshMs", 5000)))
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  //   omarchy-shell sonlndv.vietkey toggle | english | setLanguage ja | setMode VNI
  //                                 | settings | addLanguage | open | close | togglePanel
  IpcHandler {
    target: "sonlndv.vietkey"
    function toggle(): void { root.toggle() }
    function english(): void { root.setEnglish() }
    function setLanguage(id: string): void { root.setLanguage(id) }
    function setMode(mode: string): void { root.setMode(mode) }
    function settings(): void { root.settingsOpen ? root.closeSettings() : root.openSettings("") }
    function addLanguage(): void { root.openPicker() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function togglePanel(): void { root.opened ? root.close() : root.open() }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property real openPanelIndicatorWidth: iconRow.implicitWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  // ------------------------------------------------------------- bar pill

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: iconRow.implicitWidth + Style.space(12)
    tooltipText: root.opened ? "" : "Omakey · "
      + (root.running ? root.currentLanguage.name + (root.modeText ? " (" + root.modeText + ")" : "") : "fcitx5 isn't running")
      + "\nClick: menu · Right click / Ctrl+Shift: English ↔ "
      + (root.lastLanguage ? root.lastLanguage.name : "last language")
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggle()
      else root.opened ? root.close() : root.open()
    }

    Row {
      id: iconRow
      anchors.centerIn: parent
      spacing: Style.space(5)
      opacity: root.running ? 1 : 0.5

      Badge {
        anchors.verticalCenter: parent.verticalCenter
        size: Style.space(15)
        glyph: root.currentLanguage.badge
        fill: root.english ? root.foreground : Color.accent
        ink: root.bar && !root.bar.transparent ? root.bar.background : Color.background
        fontFamily: root.fontFamily
      }

      Text {
        visible: root.showModeName && root.modeText !== ""
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.modeText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ------------------------------------------------------------- settings

  LazyLoader {
    active: root.settingsOpen
    SettingsWindow {
      host: root
      language: Catalogue.byId(root.settingsLanguage) || Catalogue.languageForEngine("")
      languages: root.languages
      lastLanguage: root.lastLanguage
      fontFamily: root.fontFamily
      screen: button.QsWindow.window ? button.QsWindow.window.screen : null
    }
  }

  // ----------------------------------------------------------------- menu

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    padding: Style.space(6)
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(menuColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dy !== 0 ? dy : dx)
      }
      onActivateRequested: {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (root.actionable(root.cursorIndex)) root.activate(root.rows[root.cursorIndex])
      }
      // Esc steps back out of Add/Remove first, then closes.
      onCloseRequested: root.view !== "menu" ? root.showView("menu") : root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: menuColumn
        width: parent.width

        Repeater {
          model: root.rows

          Loader {
            required property var modelData
            required property int index
            width: menuColumn.width
            sourceComponent: modelData.kind === "separator" ? separatorRow
              : modelData.kind === "hint" ? hintRow : menuRow

            property var rowData: modelData
            property int rowIndex: index
          }
        }
      }
    }
  }

  Component {
    id: separatorRow

    Item {
      implicitHeight: Style.space(9)
      PanelSeparator {
        anchors.verticalCenter: parent.verticalCenter
        x: Style.space(8)
        width: parent.width - Style.space(16)
        foreground: Color.popups.text
      }
    }
  }

  Component {
    id: hintRow

    Item {
      implicitHeight: Style.space(24)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        x: Style.space(26)
        textFormat: Text.PlainText
        text: parent.parent ? parent.parent.rowData.label : ""
        color: Color.popups.text
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Component {
    id: menuRow

    CursorSurface {
      id: rowItem
      readonly property var row: parent ? parent.rowData : null
      readonly property int rowIndex: parent ? parent.rowIndex : -1
      readonly property bool hot: root.cursorActive && root.cursorIndex === rowIndex
      readonly property bool sub: !!row && row.kind === "sub"
      readonly property color textColor: Color.popups.text

      implicitHeight: Style.space(sub ? 24 : 28)
      implicitWidth: rowContent.implicitWidth + Style.space(22)
      hasCursor: hot
      foreground: Color.popups.text
      opacity: row && row.disabled && row.kind !== "pick" ? 0.5 : 1

      Row {
        id: rowContent
        anchors.verticalCenter: parent.verticalCenter
        x: Style.space(rowItem.sub ? 34 : 6)
        spacing: Style.space(6)

        Text {
          width: Style.space(14)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: rowItem.row && rowItem.row.kind === "pick" ? (rowItem.row.checked ? "☑" : "☐")
            : rowItem.row && rowItem.row.checked ? "✓" : ""
          color: rowItem.textColor
          opacity: rowItem.row && rowItem.row.kind === "pick" && rowItem.row.disabled ? 0.5 : 1
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Item {
          visible: !!rowItem.row && (!!rowItem.row.glyph || !!rowItem.row.icon)
          width: Style.space(22)
          height: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter

          Badge {
            visible: !!rowItem.row && !!rowItem.row.glyph
            anchors.centerIn: parent
            size: Style.space(17)
            glyph: rowItem.row && rowItem.row.glyph ? rowItem.row.glyph : ""
            fill: rowItem.textColor
            ink: Color.popups.background
            fontFamily: root.fontFamily
          }

          Text {
            visible: !!rowItem.row && !rowItem.row.glyph && !!rowItem.row.icon
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: rowItem.row && rowItem.row.icon ? rowItem.row.icon : ""
            color: rowItem.textColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: rowItem.row ? rowItem.row.label : ""
          color: rowItem.textColor
          opacity: rowItem.sub ? 0.8 : 1
          font.family: root.fontFamily
          font.pixelSize: rowItem.sub ? Style.font.caption : Style.font.body
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: rowItem.row && rowItem.row.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse && root.actionable(rowItem.rowIndex)) {
          root.cursorActive = true
          root.cursorIndex = rowItem.rowIndex
        }
        onClicked: root.activate(rowItem.row)
      }
    }
  }
}
