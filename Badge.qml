import QtQuick
import qs.Commons

// Filled rounded badge with a short code ("EN", "VI").
Item {
  id: root

  property string glyph: ""
  property color fill: Color.foreground
  property color ink: Color.background
  property real size: Style.space(16)
  property string fontFamily: Style.font.family

  implicitHeight: size
  implicitWidth: glyph.length > 1 ? Math.max(size, label.implicitWidth + size * 0.4) : size

  Rectangle {
    anchors.fill: parent
    radius: Math.max(Math.round(root.size * 0.2), Math.min(Style.cornerRadius, root.size * 0.3))
    color: root.fill
  }

  Text {
    id: label
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: root.glyph
    color: root.ink
    font.family: root.fontFamily
    font.bold: true
    font.pixelSize: Math.round(root.size * (root.glyph.length > 1 ? 0.6 : 0.72))
  }
}
