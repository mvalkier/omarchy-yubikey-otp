import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Providers.js" as Providers

// The panel with the YubiKey's OTP accounts.
//
// Opening takes two steps. First the key blinks until you touch it; the panel
// stays closed meanwhile and only the logo in the bar blinks along. The panel
// opens only after the touch. With no key plugged in, the panel opens straight
// away with "Connect a YubiKey" and the helper script waits for a key.
//
// All key I/O goes through scripts/yk-otp. Every close drops the codes from
// memory, so reopening asks for a touch again.
Panel {
  id: root
  moduleName: "melkweg.yubikey-otp"
  // The bar widget owns the IPC route; two handlers on the same target are not
  // allowed.
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // The bar must see the button as the owner, not this hidden panel.
  readonly property var barIdentity: hostWidget || root
  function switchPanel(direction) {
    return root.bar ? root.bar.switchPanelFrom(root.barIdentity, direction) : false
  }

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")
  readonly property string helper: root.pluginDir + "scripts/yk-otp"
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  // ── State ──────────────────────────────────────────────────────────────
  // "closed" | "waiting" | "no_key" | "open" | "error"
  property string phase: "closed"
  // The bar widget blinks the logo on this.
  readonly property bool waitingForTouch: phase === "waiting"
  property string errorText: ""
  property var serial: null
  property string keyName: ""
  property real now: Date.now()
  // The row waiting for a touch, the row whose touch failed, and the row that
  // was just copied.
  property string busyId: ""
  property string failedId: ""
  property string copiedId: ""

  // A ListModel rather than a JS array: a Repeater that gets a new array
  // rebuilds all its rows, and with a refresh every period that looks like
  // flicker. Roles: id, issuer, icon, name, period, touch, code, validMs.
  ListModel { id: accounts }

  function rowToModel(r) {
    return {
      id: String(r.id),
      issuer: String(r.issuer || ""),
      icon: String(r.icon || ""),
      name: String(r.name || ""),
      period: Number(r.period) || 30,
      touch: r.touch === true,
      code: String(r.code || ""),
      validMs: (Number(r.validUntil) || 0) * 1000
    }
  }

  function findRow(id) {
    for (var i = 0; i < accounts.count; i++) {
      if (accounts.get(i).id === id) return i
    }
    return -1
  }

  function fillAccounts(rows) {
    accounts.clear()
    for (var i = 0; i < rows.length; i++) accounts.append(root.rowToModel(rows[i]))
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────
  // These three override Panel's, so IPC, switchPanelFrom and
  // closeForPopoutSwitch all take the same path.
  function open() {
    if (root.phase !== "closed") return
    root.phase = "waiting"
    unlockProc.running = false
    unlockProc.running = true
  }

  function close() {
    unlockProc.running = false
    codesProc.running = false
    codeProc.running = false
    accounts.clear()
    root.serial = null
    root.keyName = ""
    root.busyId = ""
    root.failedId = ""
    root.copiedId = ""
    root.errorText = ""
    root.phase = "closed"
    root.controller.hide()
  }

  // A click while blinking cancels.
  function toggle() { root.phase === "closed" ? root.open() : root.close() }

  // Closing through the controller itself, for example by clicking outside the
  // panel. While "waiting" the panel is usually still closed and the blinking
  // simply continues.
  onOpenedChanged: if (!opened && root.phase !== "closed" && root.phase !== "waiting") root.close()

  function parseLine(line) {
    try {
      return JSON.parse(String(line))
    } catch (e) {
      return null
    }
  }

  function handleUnlock(line) {
    var d = root.parseLine(line)
    if (!d) return
    if (d.step === "touch") {
      root.phase = "waiting"
      return
    }
    if (d.ok === true) {
      root.fillAccounts(d.accounts || [])
      root.serial = d.serial
      root.keyName = String(d.name || "YubiKey")
      root.now = Date.now()
      root.phase = "open"
      root.controller.show()
      return
    }
    var reason = String(d.reason || "unknown error")
    if (reason === "no_key") {
      root.phase = "no_key"
      root.controller.show()
    } else if (reason === "no_touch") {
      root.close()
    } else {
      root.errorText = reason
      root.phase = "error"
      root.controller.show()
    }
  }

  // Updates only the rows that need no touch. A just-touched code in a touch
  // row thus stays until its ring runs out.
  function handleCodes(line) {
    var d = root.parseLine(line)
    if (!d || root.phase !== "open") return
    if (d.ok !== true) {
      if (d.reason === "no_key") root.close()
      return
    }
    var rows = d.accounts || []
    var sameSet = accounts.count === rows.length
    for (var i = 0; sameSet && i < rows.length; i++) {
      if (accounts.get(i).id !== String(rows[i].id)) sameSet = false
    }
    // The list is rebuilt only when the accounts themselves change.
    if (!sameSet) {
      root.fillAccounts(rows)
      return
    }
    for (var k = 0; k < rows.length; k++) {
      var fresh = root.rowToModel(rows[k])
      if (fresh.touch || accounts.get(k).touch) continue
      if (accounts.get(k).code !== fresh.code) accounts.setProperty(k, "code", fresh.code)
      if (accounts.get(k).validMs !== fresh.validMs) accounts.setProperty(k, "validMs", fresh.validMs)
    }
  }

  function handleCode(line) {
    var d = root.parseLine(line)
    if (!d || d.step === "touch") return
    var id = String(d.id || root.busyId)
    if (d.ok === true) {
      var i = root.findRow(id)
      if (i >= 0) {
        accounts.setProperty(i, "validMs", (Number(d.validUntil) || 0) * 1000)
        accounts.setProperty(i, "code", String(d.code || ""))
      }
      root.now = Date.now()
      root.busyId = ""
      return
    }
    root.failedId = id
    root.busyId = ""
    if (d.reason === "no_key") root.close()
  }

  function requestCode(id) {
    if (codeProc.running || codesProc.running) return
    root.busyId = id
    root.failedId = ""
    codeProc.command = [root.helper, "code", String(root.serial), id]
    codeProc.running = true
  }

  function clickRow(index) {
    var r = accounts.get(index)
    if (!r) return
    if (r.code !== "") {
      root.copyToClipboard(r.code)
      root.copiedId = r.id
      copiedTimer.restart()
    } else if (r.touch) {
      root.requestCode(r.id)
    }
  }

  // The code goes to wl-copy on stdin, never in the arguments: process arguments
  // are readable by every local user through /proc for as long as the process runs.
  // wl-copy reads until EOF, so stdin is closed right after the write.
  function copyToClipboard(text) {
    clipboardProc.running = false
    clipboardProc.pending = text
    clipboardProc.stdinEnabled = true
    clipboardProc.running = true
  }

  Process {
    id: clipboardProc
    property string pending: ""
    command: ["wl-copy"]
    onStarted: {
      write(pending)
      pending = ""
      stdinEnabled = false
    }
  }

  Process {
    id: unlockProc
    command: [root.helper, "unlock"]
    stdout: SplitParser { onRead: function (line) { root.handleUnlock(line) } }
    // A crashed process must not leave the blinking hanging.
    onRunningChanged: if (!running && root.phase === "waiting") root.close()
  }

  Process {
    id: codesProc
    command: [root.helper, "codes", String(root.serial)]
    stdout: SplitParser { onRead: function (line) { root.handleCodes(line) } }
  }

  Process {
    id: codeProc
    stdout: SplitParser { onRead: function (line) { root.handleCode(line) } }
    onRunningChanged: if (!running) root.busyId = ""
  }

  // Runs the rings down and clears expired codes.
  Timer {
    interval: 100
    repeat: true
    running: root.phase === "open"
    onTriggered: {
      root.now = Date.now()
      for (var i = 0; i < accounts.count; i++) {
        var r = accounts.get(i)
        if (r.code === "" || r.validMs > root.now) continue
        if (r.touch) accounts.setProperty(i, "code", "")
        else if (!codesProc.running && !codeProc.running) codesProc.running = true
      }
    }
  }

  Timer {
    id: copiedTimer
    interval: 1500
    onTriggered: root.copiedId = ""
  }

  // ── The panel ──────────────────────────────────────────────────────────
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(320))
    // No fixed limit: the panel grows with the number of accounts up to the
    // available screen height, and only scrolls after that.
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }

      Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: column
          width: flick.width
          spacing: Style.space(10)

          Text {
            Layout.fillWidth: true
            visible: root.phase === "no_key"
            text: "Connect a YubiKey"
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            Layout.fillWidth: true
            visible: root.phase === "waiting"
            text: "Touch your YubiKey"
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }

          Text {
            Layout.fillWidth: true
            visible: root.phase === "error"
            text: root.errorText
            color: Color.urgent
            wrapMode: Text.Wrap
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            Layout.fillWidth: true
            visible: root.phase === "open"
            text: root.keyName + " · " + root.serial
            color: root.barForeground
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Rectangle {
            Layout.fillWidth: true
            visible: root.phase === "open" && accounts.count > 0
            implicitHeight: Math.max(1, Style.space(1))
            color: Qt.alpha(root.barForeground, 0.15)
          }

          Text {
            Layout.fillWidth: true
            visible: root.phase === "open" && accounts.count === 0
            text: "No OTP accounts on this YubiKey"
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Repeater {
            model: root.phase === "open" ? accounts : null

            delegate: Item {
              id: row
              Layout.fillWidth: true
              implicitHeight: rowLine.implicitHeight

              readonly property bool busy: root.busyId === model.id
              readonly property bool hasCode: model.code !== ""
              readonly property bool failed: root.failedId === model.id
              readonly property real remaining: Math.max(0, Math.min(1,
                (model.validMs - root.now) / (model.period * 1000)))

              RowLayout {
                id: rowLine
                width: parent.width
                spacing: Style.space(10)

                ProviderIcon {
                  Layout.alignment: Qt.AlignVCenter
                  issuer: model.issuer
                  file: model.icon
                  size: Style.space(32)
                  fontFamily: root.fontFamily
                  blinking: row.busy
                  copied: root.copiedId === model.id
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(2)

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(6)

                    Text {
                      Layout.maximumWidth: row.width * 0.5
                      text: model.issuer
                      color: root.barForeground
                      elide: Text.ElideRight
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                    }

                    Text {
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignBaseline
                      text: model.name
                      color: Color.muted
                      elide: Text.ElideRight
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(8)

                    // Only the display is grouped; copying uses the code
                    // without spaces.
                    Text {
                      visible: row.hasCode && !row.busy
                      text: Providers.group(model.code)
                      color: root.barForeground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.display
                      font.bold: true
                    }

                    // Runs down clockwise from twelve o'clock, right after the
                    // code it belongs to.
                    Item {
                      id: ring
                      visible: row.hasCode && !row.busy
                      Layout.alignment: Qt.AlignVCenter
                      implicitWidth: Style.space(24)
                      implicitHeight: Style.space(24)

                      readonly property real thickness: Style.space(3)
                      // Accent colour; red in the last five seconds.
                      readonly property color tint: (model.validMs - root.now) <= 5000
                        ? Color.urgent : Color.accent

                      Shape {
                        anchors.fill: parent
                        antialiasing: true
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                          fillColor: "transparent"
                          strokeColor: Qt.alpha(ring.tint, 0.25)
                          strokeWidth: ring.thickness
                          capStyle: ShapePath.FlatCap
                          PathAngleArc {
                            centerX: ring.width / 2
                            centerY: ring.height / 2
                            radiusX: (ring.width - ring.thickness) / 2
                            radiusY: (ring.height - ring.thickness) / 2
                            startAngle: -90
                            sweepAngle: 360
                          }
                        }

                        ShapePath {
                          fillColor: "transparent"
                          strokeColor: ring.tint
                          strokeWidth: ring.thickness
                          capStyle: ShapePath.FlatCap
                          PathAngleArc {
                            centerX: ring.width / 2
                            centerY: ring.height / 2
                            radiusX: (ring.width - ring.thickness) / 2
                            radiusY: (ring.height - ring.thickness) / 2
                            startAngle: -90
                            sweepAngle: 360 * row.remaining
                          }
                        }
                      }
                    }

                    Text {
                      visible: row.busy || !row.hasCode
                      Layout.fillWidth: true
                      text: row.busy ? "Touch your YubiKey…"
                        : row.failed ? "No touch — click again"
                        : "Click and touch your YubiKey"
                      // The blinking icon is the signal; only a failed touch is
                      // red.
                      color: row.failed ? Color.urgent : Color.muted
                      elide: Text.ElideRight
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clickRow(index)
              }
            }
          }
        }
      }
    }
  }
}
