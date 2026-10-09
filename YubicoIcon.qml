import QtQuick
import QtQuick.Shapes
import qs.Commons

// The Yubico logo: a ring with a Y inside. There is no Nerd Font glyph for it,
// so the path comes from Simple Icons (CC0). The path is drawn in a 24×24 box
// and scaled to iconSize here.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Shape {
    width: 24
    height: 24
    scale: root.iconSize / 24
    transformOrigin: Item.TopLeft
    antialiasing: true
    layer.enabled: true
    layer.samples: 4

    // The default OddEvenFill turns the two circles into a ring by itself.
    ShapePath {
      fillColor: root.color
      strokeColor: "transparent"
      strokeWidth: 0
      PathSvg {
        path: "m12.356 12.388 2.521-7.138h3.64l-6.135 15.093H8.539l1.755-4.136L6 5.25h3.717ZM12 0C5.381 0 0 5.381 0 12s5.381 12 12 12 12-5.381 12-12S18.619 0 12 0Zm0 1.5c5.808 0 10.5 4.692 10.5 10.5S17.808 22.5 12 22.5 1.5 17.808 1.5 12 6.192 1.5 12 1.5Z"
      }
    }
  }
}
