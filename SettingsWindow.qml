pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Catalogue.mjs" as Catalogue

// Keymarchy Settings: one dashboard for every enabled language.
//
// Left, the languages in Ctrl+Shift cycle order (the fcitx5 group order) with
// a check on the active one: move up/down, remove, or add more through the
// menu's picker. Right, the selected language's options: the Vietnamese page for
// Vietnamese, an engine picker where a language has several engines in the
// group, a link to fcitx5-configtool otherwise, and nothing to set for
// keyboard layouts. Below, the shortcut and bar options. Every change applies
// straight away. Esc, the scrim or Close dismiss it.
//
// Keys: ↑/↓ select · Ctrl+↑/↓ move · Enter use · Delete remove · Tab or →
// options (arrows move, Enter/Space toggles) · Esc close.
PanelWindow {
  id: win

  // BarWidget: languages, current, config, viEngine, settingsLanguage, switchTo(),
  // setOption(), moveLanguage(), removeLanguage(), addFromSettings(),
  // openFcitxConfig(), setShowModeName(), closeSettings()
  property var host: null
  property string fontFamily: Style.font.family

  readonly property var languages: host ? host.languages : []
  readonly property var config: host ? host.config : ({})
  readonly property string activeId: host ? host.currentLanguage.id : Catalogue.ENGLISH
  readonly property int selectedIndex: Math.max(0, languages.findIndex(function(l) {
    return !!win.host && l.id === win.host.settingsLanguage
  }))
  readonly property var language: languages.length > 0 ? languages[selectedIndex] : null
  // "english", "vietnamese", "layout", "modes" (several engines) or "engine".
  readonly property string kind: !language || language.id === Catalogue.ENGLISH ? "english"
    : language.id === Catalogue.VIETNAMESE ? "vietnamese"
    : language.xkbCode ? "layout"
    : language.engines.length > 1 ? "modes" : "engine"

  readonly property color text: Color.popups.text
  readonly property color surface: Color.popups.background
  readonly property color accent: Color.accent

  readonly property var inputMethods: [
    { value: "Telex", hint: "aa → â · dd → đ · s f r x j → dấu" },
    { value: "VNI", hint: "a6 → â · d9 → đ · 1 2 3 4 5 → dấu" }
  ]
  // Charsets and options as the Vietnamese engine in the group (Bamboo, or
  // Unikey from 2.0.x) names them; SetConfig takes these values verbatim.
  readonly property string viEngine: host ? host.viEngine : "bamboo"
  readonly property var charsets: Catalogue.vietnameseCharsets(viEngine)
  readonly property var allOptions: [
    { key: "SpellCheck", vi: "Kiểm tra chính tả", en: "Spell check" },
    { key: "AutoNonVnRestore", vi: "Tự khôi phục từ không phải tiếng Việt", en: "Restore non-Vietnamese words (class, windows…)" },
    { key: "ModernStyle", vi: "Đặt dấu kiểu mới: oà, uý", en: "Modern tone placement (oà, uý instead of òa, úy)" },
    { key: "FreeMarking", vi: "Cho phép gõ dấu tự do", en: "Type tone marks anywhere in the word" },
    { key: "ProcessWAtBegin", vi: "Xử lý W ở đầu từ", en: "W at the start of a word becomes Ư" }
  ]
  readonly property var options: allOptions.filter(function(o) {
    return Catalogue.vietnameseOptions(win.viEngine).indexOf(o.key) >= 0
  })

  // Keyboard cursor: the language list (rows 0..n-1, then "Add language…"
  // at n) or the detail pane's controls, in detailItems order.
  property bool inDetail: false
  property int listCursor: selectedIndex
  property int detailCursor: 0
  readonly property var detailItems: buildDetailItems(kind, language)
  // Detail index of the first charset and first option (Vietnamese page).
  readonly property int charsetStart: inputMethods.length
  readonly property int optionStart: inputMethods.length + charsets.length

  function hintFor(value) {
    for (var i = 0; i < inputMethods.length; i++)
      if (inputMethods[i].value === value) return inputMethods[i].hint
    return ""
  }

  function buildDetailItems(kind, language) {
    var out = []
    if (kind === "vietnamese") {
      for (var m = 0; m < inputMethods.length; m++) out.push({ key: "InputMethod", value: inputMethods[m].value })
      for (var c = 0; c < charsets.length; c++) out.push({ key: "OutputCharset", value: charsets[c] })
      for (var o = 0; o < options.length; o++) out.push({ toggle: options[o].key })
    } else if (kind === "modes") {
      for (var e = 0; e < language.engines.length; e++) out.push({ engine: language.engines[e] })
    } else if (kind === "engine") {
      out.push({ fcitx: true })
    }
    out.push({ showModeName: true })
    return out
  }

  function hot(i) {
    return inDetail && detailCursor === i
  }

  function activateDetail(i) {
    var item = detailItems[i]
    if (!item || !host) return
    if (item.key) host.setOption(item.key, item.value)
    else if (item.toggle) host.setOption(item.toggle, config[item.toggle] === "True" ? "False" : "True")
    else if (item.engine) host.switchTo(item.engine)
    else if (item.fcitx) host.openFcitxConfig()
    else if (item.showModeName) host.setShowModeName(!host.showModeName)
  }

  function selectRow(i) {
    listCursor = Math.max(0, Math.min(i, languages.length))
    if (listCursor < languages.length && languages[listCursor].id !== language.id) {
      host.selectSettingsLanguage(languages[listCursor].id)
      detailCursor = 0
    }
  }

  function useLanguage(i) {
    if (i < languages.length) host.switchTo(languages[i].engines[0])
    else host.addFromSettings()
  }

  function canMove(i, delta) {
    return i > 0 && i + delta > 0 && i + delta < languages.length
  }

  function move(i, delta) {
    if (!canMove(i, delta)) return
    host.moveLanguage(languages[i].id, delta)
    listCursor = selectedIndex
  }

  function remove(i) {
    if (i > 0 && i < languages.length) host.removeLanguage(languages[i].engines)
  }

  // The group is re-read every few seconds; keep both cursors in range
  // without resetting them.
  onLanguagesChanged: listCursor = Math.min(listCursor, languages.length)
  onDetailItemsChanged: detailCursor = Math.min(detailCursor, detailItems.length - 1)

  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "keymarchy-settings"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.55)
    MouseArea { anchors.fill: parent; onClicked: win.host.closeSettings() }
  }

  Item {
    id: keyCatcher
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: win.host.closeSettings()
    Keys.onPressed: function(event) {
      var key = event.key
      var ctrl = (event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) !== 0
      var up = key === Qt.Key_Up || key === Qt.Key_K
      var down = key === Qt.Key_Down || key === Qt.Key_J
      var enter = key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space
      if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
        win.inDetail = !win.inDetail
        win.detailCursor = Math.min(win.detailCursor, win.detailItems.length - 1)
      } else if (!win.inDetail) {
        if (up && ctrl) win.move(win.listCursor, -1)
        else if (down && ctrl) win.move(win.listCursor, 1)
        else if (up) win.selectRow(win.listCursor - 1)
        else if (down) win.selectRow(win.listCursor + 1)
        else if (key === Qt.Key_Right || key === Qt.Key_L) win.inDetail = true
        else if (enter) win.useLanguage(win.listCursor)
        else if (key === Qt.Key_Delete) win.remove(win.listCursor)
        else return
      } else {
        if (up || key === Qt.Key_Left || key === Qt.Key_H) {
          if (win.detailCursor === 0) win.inDetail = false
          else win.detailCursor--
        } else if (down || key === Qt.Key_Right || key === Qt.Key_L) {
          win.detailCursor = Math.min(win.detailCursor + 1, win.detailItems.length - 1)
        } else if (enter) {
          win.activateDetail(win.detailCursor)
        } else {
          return
        }
      }
      event.accepted = true
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Style.space(700)
      height: content.implicitHeight + Style.space(48)
      scale: Math.min(1, (keyCatcher.width - Style.space(32)) / Math.max(1, width),
        (keyCatcher.height - Style.space(32)) / Math.max(1, height))
      radius: Style.cornerRadius
      color: win.surface
      border.width: Math.max(1, Style.space(2))
      border.color: Color.popups.border

      MouseArea { anchors.fill: parent; onClicked: {} }

      ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Style.space(24)
        spacing: Style.space(16)

        // ------------------------------------------------------- header
        ColumnLayout {
          spacing: 0
          Text {
            text: "Keymarchy"
            color: win.text
            font.family: win.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            text: "Input languages · fcitx5"
            color: win.text
            opacity: 0.6
            font.family: win.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(20)

          // --------------------------------------------------- languages
          ColumnLayout {
            Layout.preferredWidth: Style.space(320)
            Layout.maximumWidth: Style.space(320)
            Layout.alignment: Qt.AlignTop
            spacing: Style.space(2)

            SectionTitle { en: "Languages · " + (win.host ? win.host.switchKeyLabel : "Ctrl+Shift") + " order" }

            Repeater {
              model: win.languages
              LanguageRow {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                language: modelData
                rowIndex: index
              }
            }

            Rectangle {
              id: addRow
              Layout.fillWidth: true
              Layout.topMargin: Style.space(4)
              implicitHeight: Style.space(34)
              radius: Style.cornerRadius
              readonly property bool hot: !win.inDetail && win.listCursor === win.languages.length
              color: hot || addMouse.containsMouse ? Qt.rgba(win.text.r, win.text.g, win.text.b, 0.1) : "transparent"
              border.width: hot ? 1 : 0
              border.color: win.accent

              Row {
                anchors.verticalCenter: parent.verticalCenter
                x: Style.space(8)
                spacing: Style.space(8)
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰐕"
                  color: win.text
                  font.family: win.fontFamily
                  font.pixelSize: Style.font.title
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Add language…"
                  color: win.text
                  font.family: win.fontFamily
                  font.pixelSize: Style.font.body
                }
              }

              MouseArea {
                id: addMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.host.addFromSettings()
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.leftMargin: Style.space(8)
              wrapMode: Text.WordWrap
              text: "Opens the picker in the Keymarchy menu. Installing a language may ask to restart fcitx5; it asks first."
              color: win.text
              opacity: 0.6
              font.family: win.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // ------------------------------------------------------ detail
          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Style.space(14)

            RowLayout {
              spacing: Style.space(10)

              Badge {
                size: Style.space(26)
                glyph: win.language ? win.language.badge : "EN"
                fill: win.accent
                ink: win.surface
                fontFamily: win.fontFamily
              }

              ColumnLayout {
                spacing: 0
                Text {
                  text: win.host && win.language ? win.host.displayName(win.language) : ""
                  color: win.text
                  font.family: win.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  text: win.kind === "vietnamese" ? "Bộ gõ tiếng Việt · Vietnamese keyboard"
                    : win.language ? win.language.engines.join(", ") : ""
                  color: win.text
                  opacity: 0.6
                  font.family: win.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            // ------------------------------------- English / layout / engine
            Text {
              visible: win.kind === "english" || win.kind === "layout" || win.kind === "engine"
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
              text: win.kind === "english"
                ? "English types with your keyboard layout (" + (win.host && win.host.groupLayout ? win.host.groupLayout : "us") + ")."
                  + (win.languages.length > 1 ? " There is nothing to set here." : " Add a language from the list to start switching.")
                : win.kind === "layout"
                ? "Keyboard layout: " + win.language.name + " (" + win.language.xkbCode + ")"
                : win.language ? "Keymarchy has no settings page of its own for " + win.language.name
                  + " yet. Its options live in fcitx5's configuration tool (fcitx5-configtool)." : ""
              color: win.text
              font.family: win.fontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              visible: win.kind === "english" && win.languages.length > 1
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
              text: win.host ? win.host.cycleHint : ""
              color: win.text
              opacity: 0.6
              font.family: win.fontFamily
              font.pixelSize: Style.font.caption
            }

            Chip {
              visible: win.kind === "engine"
              label: "Open fcitx5 settings…"
              hot: win.kind === "engine" && win.hot(0)
              onClicked: win.host.openFcitxConfig()
            }

            // --------------------------------------------- engine modes
            SectionTitle { visible: win.kind === "modes"; en: "Engine" }

            Flow {
              visible: win.kind === "modes"
              Layout.fillWidth: true
              spacing: Style.space(6)
              Repeater {
                model: win.kind === "modes" ? win.language.engines : []
                Chip {
                  required property var modelData
                  required property int index
                  label: Catalogue.engineLabel(modelData)
                  checked: !!win.host && win.host.current === modelData
                  hot: win.hot(index)
                  onClicked: win.host.switchTo(modelData)
                }
              }
            }

            Text {
              visible: win.kind === "modes"
              Layout.topMargin: -Style.space(8)
              text: "Picking one switches to it now."
              color: win.text
              opacity: 0.6
              font.family: win.fontFamily
              font.pixelSize: Style.font.caption
            }

            // --------------------------------------- Vietnamese: input method
            SectionTitle { visible: win.kind === "vietnamese"; vi: "Kiểu gõ"; en: "Input method" }

            Flow {
              visible: win.kind === "vietnamese"
              Layout.fillWidth: true
              spacing: Style.space(6)
              Repeater {
                model: win.inputMethods
                Chip {
                  required property var modelData
                  required property int index
                  label: modelData.value
                  checked: win.config.InputMethod === modelData.value
                  hot: win.kind === "vietnamese" && win.hot(index)
                  onClicked: win.host.setOption("InputMethod", modelData.value)
                }
              }
            }

            Text {
              visible: win.kind === "vietnamese"
              Layout.topMargin: -Style.space(8)
              text: win.hintFor(win.config.InputMethod)
              color: win.text
              opacity: 0.6
              font.family: win.fontFamily
              font.pixelSize: Style.font.caption
            }

            // -------------------------------------------- Vietnamese: charset
            SectionTitle { visible: win.kind === "vietnamese"; vi: "Bảng mã"; en: "Charset" }

            Flow {
              visible: win.kind === "vietnamese"
              Layout.fillWidth: true
              spacing: Style.space(6)
              Repeater {
                model: win.charsets
                Chip {
                  required property var modelData
                  required property int index
                  label: modelData
                  checked: win.config.OutputCharset === modelData
                  hot: win.kind === "vietnamese" && win.hot(win.charsetStart + index)
                  onClicked: win.host.setOption("OutputCharset", modelData)
                }
              }
            }

            // -------------------------------------------- Vietnamese: options
            SectionTitle { visible: win.kind === "vietnamese"; vi: "Tuỳ chọn"; en: "Options" }

            ColumnLayout {
              visible: win.kind === "vietnamese"
              Layout.fillWidth: true
              spacing: Style.space(2)
              Repeater {
                model: win.options
                CheckRow {
                  required property var modelData
                  required property int index
                  Layout.fillWidth: true
                  vi: modelData.vi
                  en: modelData.en
                  checked: win.config[modelData.key] === "True"
                  hot: win.kind === "vietnamese" && win.hot(win.optionStart + index)
                  onClicked: win.host.setOption(modelData.key, checked ? "False" : "True")
                }
              }
            }
          }
        }

        // ------------------------------------------------------ general
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 1
          color: win.text
          opacity: 0.15
        }

        SectionTitle { en: "General" }

        CheckRow {
          Layout.fillWidth: true
          Layout.topMargin: -Style.space(8)
          vi: "Show the mode next to the badge"
          en: "Telex / VNI, Pinyin / Zhuyin on the bar"
          checked: !!win.host && win.host.showModeName
          hot: win.hot(win.detailItems.length - 1)
          onClicked: win.host.setShowModeName(!checked)
        }

        RowLayout {
          Layout.fillWidth: true

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)
            Text {
              Layout.fillWidth: true
              text: win.host ? win.host.cycleHint + " · right click the badge does the same" : ""
              color: win.text
              font.family: win.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
              text: "↑↓ select · Ctrl+↑↓ move · Enter use · Del remove · Tab options · Esc close"
              color: win.text
              opacity: 0.6
              font.family: win.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Chip {
            label: "Close"
            checked: true
            onClicked: win.host.closeSettings()
          }
        }
      }
    }
  }

  // ----------------------------------------------------------- pieces

  component LanguageRow: Rectangle {
    id: langRow
    property var language: null
    property int rowIndex: 0
    readonly property bool selected: rowIndex === win.selectedIndex
    readonly property bool cursor: !win.inDetail && win.listCursor === rowIndex
    readonly property bool active: !!language && language.id === win.activeId

    implicitHeight: Style.space(34)
    radius: Style.cornerRadius
    color: selected ? Qt.rgba(win.text.r, win.text.g, win.text.b, 0.12)
      : langMouse.containsMouse ? Qt.rgba(win.text.r, win.text.g, win.text.b, 0.07) : "transparent"
    border.width: cursor ? 1 : 0
    border.color: win.accent

    MouseArea {
      id: langMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        win.inDetail = false
        win.selectRow(langRow.rowIndex)
      }
      onDoubleClicked: win.useLanguage(langRow.rowIndex)
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(4)
      spacing: Style.space(6)

      Text {
        Layout.preferredWidth: Style.space(14)
        text: langRow.active ? "✓" : ""
        color: win.text
        font.family: win.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Badge {
        size: Style.space(18)
        glyph: langRow.language ? langRow.language.badge : ""
        fill: langRow.active ? win.accent : win.text
        ink: win.surface
        fontFamily: win.fontFamily
      }

      Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: langRow.language ? (langRow.language.nativeName || langRow.language.name) : ""
        color: win.text
        font.family: win.fontFamily
        font.pixelSize: Style.font.body
      }

      IconButton {
        glyph: "↑"
        enabled: win.canMove(langRow.rowIndex, -1)
        onClicked: win.move(langRow.rowIndex, -1)
      }
      IconButton {
        glyph: "↓"
        enabled: win.canMove(langRow.rowIndex, 1)
        onClicked: win.move(langRow.rowIndex, 1)
      }
      IconButton {
        glyph: "󰍴"
        enabled: langRow.rowIndex > 0
        onClicked: win.remove(langRow.rowIndex)
      }
    }
  }

  component IconButton: Rectangle {
    id: iconButton
    property string glyph: ""
    signal clicked()

    implicitWidth: Style.space(22)
    implicitHeight: Style.space(22)
    radius: Math.min(Style.cornerRadius, height / 2)
    color: enabled && iconMouse.containsMouse ? Qt.rgba(win.text.r, win.text.g, win.text.b, 0.15) : "transparent"
    opacity: enabled ? 0.85 : 0.25

    Text {
      anchors.centerIn: parent
      text: iconButton.glyph
      color: win.text
      font.family: win.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: iconMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: iconButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: if (iconButton.enabled) iconButton.clicked()
    }
  }

  component SectionTitle: Text {
    property string vi: ""
    property string en: ""
    text: vi ? vi.toUpperCase() + "  ·  " + en : en.toUpperCase()
    color: win.text
    opacity: 0.75
    font.family: win.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
  }

  component Chip: Rectangle {
    id: chip
    property string label: ""
    property bool checked: false
    property bool hot: false          // keyboard cursor
    signal clicked()

    implicitWidth: chipText.implicitWidth + Style.space(20)
    implicitHeight: Style.space(30)
    radius: Math.min(Style.cornerRadius, height / 2)
    color: checked ? win.accent : (chipMouse.containsMouse || hot ? Qt.rgba(win.text.r, win.text.g, win.text.b, 0.1) : "transparent")
    border.width: hot ? 2 : 1
    border.color: checked || hot ? win.accent : Qt.rgba(win.text.r, win.text.g, win.text.b, 0.3)

    Text {
      id: chipText
      anchors.centerIn: parent
      text: chip.label
      color: chip.checked ? win.surface : win.text
      font.family: win.fontFamily
      font.pixelSize: Style.font.body
      font.bold: chip.checked
    }

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }

  component CheckRow: Rectangle {
    id: row
    property string vi: ""
    property string en: ""
    property bool checked: false
    property bool hot: false          // keyboard cursor
    signal clicked()

    implicitHeight: Style.space(40)
    radius: Style.cornerRadius
    color: rowMouse.containsMouse || hot ? Qt.rgba(win.text.r, win.text.g, win.text.b, 0.07) : "transparent"
    border.width: hot ? 1 : 0
    border.color: win.accent

    Rectangle {
      id: box
      anchors.left: parent.left
      anchors.leftMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(18)
      height: Style.space(18)
      radius: Math.min(Style.cornerRadius, Style.space(4))
      color: row.checked ? win.accent : "transparent"
      border.width: 1
      border.color: row.checked ? win.accent : Qt.rgba(win.text.r, win.text.g, win.text.b, 0.45)

      Text {
        anchors.centerIn: parent
        visible: row.checked
        text: "✓"
        color: win.surface
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    Column {
      anchors.left: box.right
      anchors.leftMargin: Style.space(12)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignLeft
        text: row.vi
        color: win.text
        font.family: win.fontFamily
        font.pixelSize: Style.font.body
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignLeft
        text: row.en
        color: win.text
        opacity: 0.55
        font.family: win.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.clicked()
    }
  }
}
