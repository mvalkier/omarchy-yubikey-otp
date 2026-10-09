import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// YubiKey OTP: the Yubico logo in the bar.
//
// A click makes the key and the logo blink; after a touch the panel opens with
// the accounts. All state lives in Panel.qml; this button only forwards and
// blinks along.
BarWidget {
  id: root
  moduleName: "melkweg.yubikey-otp"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ── Panel lifecycle ────────────────────────────────────────────────────
  // The shell looks up open/close/opened on the item that sits in the bar, so
  // they must live here and not only on the panel itself.
  readonly property var panel: panelLoader.item
  readonly property bool opened: panel ? panel.opened === true : false
  readonly property bool popoutSwitchClosing: panel ? panel.popoutSwitchClosing === true : false
  readonly property bool waiting: panel ? panel.waitingForTouch === true : false

  function open() { if (panel) panel.open() }
  function close() { if (panel) panel.close() }
  function toggle() { if (panel) panel.toggle() }
  function closeForPopoutSwitch() { if (panel) panel.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "melkweg.yubikey-otp"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.waiting ? "Touch your YubiKey" : "YubiKey OTP"
    iconComponent: Component {
      Item {
        YubicoIcon {
          id: logo
          anchors.centerIn: parent
          iconSize: Style.space(14)
          color: root.waiting
            ? (root.bar ? root.bar.urgent : Color.urgent)
            : (root.bar ? root.bar.barForeground : Color.foreground)
        }

        // Blinks while the key waits for a touch.
        SequentialAnimation {
          running: root.waiting
          loops: Animation.Infinite
          NumberAnimation { target: logo; property: "opacity"; to: 0.25; duration: 500 }
          NumberAnimation { target: logo; property: "opacity"; to: 1; duration: 500 }
          onRunningChanged: if (!running) logo.opacity = 1
        }
      }
    }
    onPressed: function (mouseButton) {
      if (mouseButton === Qt.LeftButton) root.toggle()
    }
  }
}
