import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// VietKey: English / Vietnamese (Telex or VNI) for fcitx5 + Unikey.
//
// `fcitx5-remote` prints 1 while the keyboard (English) is active and 2 while
// Unikey (Vietnamese) is. Telex vs VNI and spell check are Unikey options, read
// and written live over fcitx5's D-Bus controller, which also persists them.
//
// Left click opens the menu, right click flips English <-> Vietnamese.
Panel {
  id: root
  moduleName: "sonlndv.vietkey"
  manageIpc: false

  readonly property string configUri: "fcitx://config/inputmethod/unikey"
  readonly property var busctl: ["busctl", "--user", "call", "org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1"]

  property bool vietnamese: false
  // Unikey's live options, e.g. { InputMethod: "Telex", SpellCheck: "True" }.
  property var config: ({ InputMethod: "Telex" })
  readonly property string viMode: config.InputMethod || "Telex"
  property bool settingsOpen: false

  readonly property bool showModeName: setting("showModeName", true) !== false
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Menu rows in display order. Keyboard navigation skips separators.
  readonly property var rows: [
    { kind: "source", source: "en", glyph: "EN", label: "English" },
    { kind: "source", source: "vi", glyph: "VI", label: "Tiếng Việt — " + root.viMode },
    { kind: "separator" },
    { kind: "action", action: "settings", label: "Open Keyboard Settings…", icon: "󰌌" },
    { kind: "separator" },
    { kind: "hint", label: "Ctrl+Shift switches language" }
  ]

  property int cursorIndex: 0
  // Hide the initial highlight until keyboard navigation or hover begins.
  property bool cursorActive: false

  function isActive(row) {
    if (!row || row.kind !== "source") return false
    return row.source === "vi" ? vietnamese : !vietnamese
  }

  function actionable(i) {
    return i >= 0 && i < rows.length && (rows[i].kind === "source" || rows[i].kind === "action")
  }

  function moveCursor(delta) {
    var i = cursorIndex
    for (var step = 0; step < rows.length; step++) {
      i = (i + delta + rows.length) % rows.length
      if (actionable(i)) { cursorIndex = i; return }
    }
  }

  function activate(row) {
    if (!row) return
    if (row.kind === "source") {
      run(["fcitx5-remote", row.source === "vi" ? "-o" : "-c"])
      close()
    } else if (row.action === "settings") {
      close()
      openSettings()
    }
  }

  // ------------------------------------------------------------- fcitx5

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  function refreshConfig() {
    if (!configProc.running) configProc.running = true
  }

  // English <-> Vietnamese, keeping the chosen Vietnamese mode.
  function toggle() {
    run(["fcitx5-remote", vietnamese ? "-c" : "-o"])
  }

  function setEnglish() {
    run(["fcitx5-remote", "-c"])
  }

  // Telex or VNI, landing in Vietnamese so
  // it is usable straight away.
  function setMode(mode) {
    if (mode !== "Telex" && mode !== "VNI") return
    setOption("InputMethod", mode, "fcitx5-remote -o")
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

  function openSettings() {
    refreshConfig()
    settingsOpen = true
  }

  function closeSettings() {
    settingsOpen = false
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

  onOpenedChanged: if (opened) {
    cursorIndex = vietnamese ? 1 : 0
    cursorActive = false
    refresh()
    refreshConfig()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Process {
    id: stateProc
    command: ["fcitx5-remote"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.vietnamese = text.trim() === "2"
    }
  }

  Process {
    id: configProc
    command: root.busctl.concat(["GetConfig", "s", root.configUri])
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Values come first; the option schema follows from "UnikeyConfig".
        var values = String(text).split('"UnikeyConfig"')[0]
        var next = {}
        var re = /"([A-Za-z]+)" s "([^"]*)"/g
        var m
        while ((m = re.exec(values)) !== null) next[m[1]] = m[2]
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

  // Ctrl+Shift switches inside fcitx5, so keep the badge in step.
  Timer {
    interval: Math.max(200, Number(root.setting("pollIntervalMs", 700)))
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // Options only change from here or from fcitx5's own settings.
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refreshConfig()
  }

  //   omarchy-shell sonlndv.vietkey toggle | setMode VNI | english | settings | open
  IpcHandler {
    target: "sonlndv.vietkey"
    function toggle(): void { root.toggle() }
    function setMode(mode: string): void { root.setMode(mode) }
    function settings(): void { root.settingsOpen ? root.closeSettings() : root.openSettings() }
    function english(): void { root.setEnglish() }
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
    tooltipText: root.opened ? "" : (root.vietnamese ? "Tiếng Việt (" + root.viMode + ")" : "English")
      + "\nClick: menu · Right click / Ctrl+Shift: switch"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggle()
      else root.opened ? root.close() : root.open()
    }

    Row {
      id: iconRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      Badge {
        anchors.verticalCenter: parent.verticalCenter
        size: Style.space(15)
        glyph: root.vietnamese ? "VI" : "EN"
        fill: root.vietnamese ? Color.accent : root.foreground
        ink: root.bar && !root.bar.transparent ? root.bar.background : Color.background
        fontFamily: root.fontFamily
      }

      Text {
        visible: root.vietnamese && root.showModeName
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.viMode
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
    contentWidth: panel.fittedContentWidth(Style.space(260))
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
      onCloseRequested: root.close()
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
      readonly property bool checked: !!row && (row.kind === "source" ? root.isActive(row) : row.toggled === true)
      readonly property color textColor: Color.popups.text

      implicitHeight: Style.space(28)
      implicitWidth: rowContent.implicitWidth + Style.space(22)
      hasCursor: hot
      foreground: Color.popups.text

      Row {
        id: rowContent
        anchors.verticalCenter: parent.verticalCenter
        x: Style.space(6)
        spacing: Style.space(6)

        Text {
          width: Style.space(14)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: rowItem.checked ? "✓" : ""
          color: rowItem.textColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Item {
          visible: !!rowItem.row && (rowItem.row.kind === "source" || !!rowItem.row.icon)
          width: Style.space(22)
          height: Style.space(18)
          anchors.verticalCenter: parent.verticalCenter

          Badge {
            visible: !!rowItem.row && rowItem.row.kind === "source"
            anchors.centerIn: parent
            size: Style.space(17)
            glyph: rowItem.row && rowItem.row.glyph ? rowItem.row.glyph : ""
            fill: rowItem.textColor
            ink: Color.popups.background
            fontFamily: root.fontFamily
          }

          Text {
            visible: !!rowItem.row && !!rowItem.row.icon
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
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) {
          root.cursorActive = true
          root.cursorIndex = rowItem.rowIndex
        }
        onClicked: root.activate(rowItem.row)
      }
    }
  }
}
