import QtQuick
import QtQuick.Shapes
import qs.Commons
import "Providers.js" as Providers

// The issuer's icon. Precedence: an icon from an installed icon pack (`file`,
// found by scripts/yk-otp), then a built-in brand logo on a rounded tile, and
// otherwise a tile with the first letter.
//
// `blinking` makes the icon blink while the key waits for a touch; `copied`
// lays a check mark over it. Both are big enough to notice without reading,
// even on a scaled screen.
Item {
  id: root

  property string issuer: ""
  // Absolute path from an icon pack, or "".
  property string file: ""
  property real size: Style.space(32)
  property string fontFamily: Style.font.family
  property bool blinking: false
  property bool copied: false

  readonly property bool fromPack: root.file !== "" && packImage.status !== Image.Error
  readonly property var icon: Providers.icon(root.issuer)
  // The logo doesn't fill the whole tile, which leaves room to the edge.
  readonly property real logoSize: root.size * 0.6

  width: size
  height: size
  implicitWidth: size
  implicitHeight: size

  Item {
    id: content
    anchors.fill: parent
    // Blinking uses a factor of its own, so the binding with `copied` stays.
    property real blink: 1
    opacity: (root.copied ? 0 : 1) * blink

    Image {
      id: packImage
      anchors.fill: parent
      visible: root.fromPack
      source: root.file !== "" ? "file://" + root.file : ""
      // Rasterize at screen size; otherwise an SVG is drawn at its own, often
      // small size and then scaled up blurry.
      sourceSize.width: root.size * 2
      sourceSize.height: root.size * 2
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
      asynchronous: true
    }

    Rectangle {
      visible: !root.fromPack
      anchors.fill: parent
      radius: root.size * 0.22
      color: root.icon.tile
    }

    Shape {
      visible: !root.fromPack && root.icon.path !== ""
      x: (root.size - root.logoSize) / 2
      y: (root.size - root.logoSize) / 2
      width: 24
      height: 24
      scale: root.logoSize / 24
      transformOrigin: Item.TopLeft
      antialiasing: true
      layer.enabled: true
      layer.samples: 4

      // Simple Icons draws with the SVG default nonzero; without WindingFill
      // the inner area of the JetBrains logo disappears.
      ShapePath {
        fillColor: root.icon.foreground
        fillRule: ShapePath.WindingFill
        strokeColor: "transparent"
        strokeWidth: 0
        PathSvg { path: root.icon.path }
      }
    }

    Text {
      visible: !root.fromPack && root.icon.path === ""
      anchors.centerIn: parent
      text: root.icon.letter
      color: root.icon.foreground
      font.family: root.fontFamily
      font.pixelSize: root.size * 0.5
      font.bold: true
    }

    // The same rhythm as the logo in the bar.
    SequentialAnimation {
      running: root.blinking
      loops: Animation.Infinite
      NumberAnimation { target: content; property: "blink"; to: 0.2; duration: 500 }
      NumberAnimation { target: content; property: "blink"; to: 1; duration: 500 }
      onRunningChanged: if (!running) content.blink = 1
    }
  }

  // Briefly replaces the icon after copying.
  Rectangle {
    id: checkTile
    anchors.fill: parent
    radius: root.size * 0.22
    color: Color.accent
    visible: opacity > 0
    opacity: root.copied ? 1 : 0
    scale: root.copied ? 1 : 0.6
    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    Shape {
      x: (root.size - root.logoSize) / 2
      y: (root.size - root.logoSize) / 2
      width: 24
      height: 24
      scale: root.logoSize / 24
      transformOrigin: Item.TopLeft
      antialiasing: true
      layer.enabled: true
      layer.samples: 4

      ShapePath {
        fillColor: "transparent"
        strokeColor: Color.background
        strokeWidth: 3
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: "M 4.5 12.5 L 9.5 17.5 L 19.5 6.5" }
      }
    }
  }
}
