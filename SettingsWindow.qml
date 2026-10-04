pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Omakey language settings. Vietnamese gets the Unikey page (input method,
// charset, typing options); every change applies and persists in fcitx5
// immediately. Other engines point to fcitx5's own configuration tool for
// now. Esc, the scrim or Close dismiss it.
PanelWindow {
  id: win

  property var host: null           // BarWidget: config, setOption(), openSettings(), close
  property var language: null       // Catalogue entry being shown
  property var languages: []        // enabled languages, English first
  property var lastLanguage: null   // Ctrl+Shift target from English
  property string fontFamily: Style.font.family

  readonly property bool vietnamese: !!language && language.id === "vi"
  readonly property var config: host ? host.config : ({})
  readonly property color text: Color.popups.text
  readonly property color surface: Color.popups.background
  readonly property color accent: Color.accent

  readonly property var inputMethods: [
    { value: "Telex", hint: "aa → â · dd → đ · s f r x j → dấu" },
    { value: "VNI", hint: "a6 → â · d9 → đ · 1 2 3 4 5 → dấu" }
  ]
  readonly property var charsets: ["Unicode", "TCVN3", "VNI Win", "VIQR", "BK HCM 2", "CString", "NCR Decimal", "NCR Hex"]
  readonly property var options: [
    { key: "SpellCheck", vi: "Kiểm tra chính tả", en: "Spell check" },
    { key: "AutoNonVnRestore", vi: "Tự khôi phục từ không phải tiếng Việt", en: "Restore non-Vietnamese words (class, windows…)" },
    { key: "ModernStyle", vi: "Đặt dấu kiểu mới: oà, uý", en: "Modern tone placement (oà, uý instead of òa, úy)" },
    { key: "FreeMarking", vi: "Cho phép gõ dấu tự do", en: "Type tone marks anywhere in the word" },
    { key: "ProcessWAtBegin", vi: "Xử lý W ở đầu từ", en: "W at the start of a word becomes Ư" }
  ]

  function hintFor(value) {
    for (var i = 0; i < inputMethods.length; i++)
      if (inputMethods[i].value === value) return inputMethods[i].hint
    return ""
  }

  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omakey-settings"
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

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Style.space(560)
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
        spacing: Style.space(18)

        // ------------------------------------------------------- header
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
              text: "Omakey"
              color: win.text
              font.family: win.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: win.vietnamese ? "Bộ gõ tiếng Việt · Vietnamese keyboard"
                : win.language ? win.language.name + " · " + win.language.engines.join(", ") : ""
              color: win.text
              opacity: 0.6
              font.family: win.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // ---------------------------------------------------- languages
        Flow {
          visible: win.languages.length > 2
          Layout.fillWidth: true
          spacing: Style.space(6)
          Repeater {
            model: win.languages.slice(1)
            Chip {
              required property var modelData
              label: modelData.badge + "  " + modelData.name
              checked: !!win.language && win.language.id === modelData.id
              onClicked: win.host.openSettings(modelData.id)
            }
          }
        }

        // ------------------------------------------------ other engines
        Text {
          visible: !win.vietnamese
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: !win.language || win.language.id === "en"
            ? "English types with your keyboard layout; there is nothing to set here. Add a language from the Omakey menu."
            : "Omakey has no settings page of its own for " + win.language.name
              + " yet. Its options live in fcitx5's configuration tool (fcitx5-configtool)."
          color: win.text
          font.family: win.fontFamily
          font.pixelSize: Style.font.body
        }

        Chip {
          visible: !win.vietnamese && !!win.language && win.language.id !== "en"
          label: "Open fcitx5 settings…"
          onClicked: win.host.openFcitxConfig()
        }

        // ------------------------------------------------- input method
        SectionTitle { visible: win.vietnamese; vi: "Kiểu gõ"; en: "Input method" }

        Flow {
          visible: win.vietnamese
          Layout.fillWidth: true
          spacing: Style.space(6)
          Repeater {
            model: win.inputMethods
            Chip {
              required property var modelData
              label: modelData.value
              checked: win.config.InputMethod === modelData.value
              onClicked: win.host.setOption("InputMethod", modelData.value)
            }
          }
        }

        Text {
          visible: win.vietnamese
          Layout.topMargin: -Style.space(8)
          text: win.hintFor(win.config.InputMethod)
          color: win.text
          opacity: 0.6
          font.family: win.fontFamily
          font.pixelSize: Style.font.caption
        }

        // ------------------------------------------------------ charset
        SectionTitle { visible: win.vietnamese; vi: "Bảng mã"; en: "Charset" }

        Flow {
          visible: win.vietnamese
          Layout.fillWidth: true
          spacing: Style.space(6)
          Repeater {
            model: win.charsets
            Chip {
              required property var modelData
              label: modelData
              checked: win.config.OutputCharset === modelData
              onClicked: win.host.setOption("OutputCharset", modelData)
            }
          }
        }

        // ------------------------------------------------------ options
        SectionTitle { visible: win.vietnamese; vi: "Tuỳ chọn"; en: "Options" }

        ColumnLayout {
          visible: win.vietnamese
          Layout.fillWidth: true
          spacing: Style.space(2)
          Repeater {
            model: win.options
            CheckRow {
              required property var modelData
              Layout.fillWidth: true
              vi: modelData.vi
              en: modelData.en
              checked: win.config[modelData.key] === "True"
              onClicked: win.host.setOption(modelData.key, checked ? "False" : "True")
            }
          }
        }

        // ------------------------------------------------------- footer
        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: Style.space(4)

          Text {
            Layout.fillWidth: true
            text: win.vietnamese ? "Chuyển Anh ↔ Việt · Switch: Ctrl+Shift"
              : "Ctrl+Shift: English ↔ " + (win.lastLanguage ? win.lastLanguage.name : "last language")
            color: win.text
            opacity: 0.6
            font.family: win.fontFamily
            font.pixelSize: Style.font.caption
          }

          Chip {
            label: win.vietnamese ? "Đóng · Close" : "Close"
            checked: true
            onClicked: win.host.closeSettings()
          }
        }
      }
    }
  }

  // ----------------------------------------------------------- pieces

  component SectionTitle: Text {
    property string vi: ""
    property string en: ""
    text: vi.toUpperCase() + "  ·  " + en
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
    signal clicked()

    implicitWidth: chipText.implicitWidth + Style.space(20)
    implicitHeight: Style.space(30)
    radius: Math.min(Style.cornerRadius, height / 2)
    color: checked ? win.accent : (chipMouse.containsMouse ? Qt.rgba(win.text.r, win.text.g, win.text.b, 0.1) : "transparent")
    border.width: 1
    border.color: checked ? win.accent : Qt.rgba(win.text.r, win.text.g, win.text.b, 0.3)

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
    signal clicked()

    implicitHeight: Style.space(40)
    radius: Style.cornerRadius
    color: rowMouse.containsMouse ? Qt.rgba(win.text.r, win.text.g, win.text.b, 0.07) : "transparent"

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
