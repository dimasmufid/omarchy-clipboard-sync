import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "dimasmufid.clipboard-sync"
  ipcTarget: "dimasmufid.clipboard-sync"
  manageIpc: false

  property int cursorIndex: 0
  property bool cursorActive: false
  property bool confirmOpen: false
  property string confirmDeviceId: ""
  property string confirmDeviceName: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property int actionCount: 3
  readonly property int cursorCount: actionCount + sync.devices.length
  readonly property bool hasStatusMessage: sync.lastError !== "" || sync.lastMessage !== ""
  readonly property string barIcon: {
    if (sync.dependencyState === "missing" || sync.dependencyState === "error") return "󰅖"
    if (sync.paused) return "󰏤"
    if (sync.busy) return "󰔟"
    if (sync.connected) return "󰅇"
    return "󰅙"
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    sync.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setSelectedDevice(deviceId) {
    persistSettings({ selectedDeviceId: String(deviceId || "") })
  }

  function togglePaused() {
    var nextPaused = !sync.paused
    persistSettings({ paused: nextPaused })
    sync.lastMessage = nextPaused ? "Clipboard sharing paused." : "Clipboard sharing resumed."
    sync.lastError = ""
  }

  function requestUnpair(device) {
    if (!device || !device.id) return
    confirmDeviceId = String(device.id)
    confirmDeviceName = String(device.name || "device")
    confirmOpen = true
  }

  function cancelUnpair() {
    confirmOpen = false
    confirmDeviceId = ""
    confirmDeviceName = ""
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }

  function confirmUnpair() {
    var id = confirmDeviceId
    cancelUnpair()
    sync.unpair(id)
  }

  function moveCursor(delta) {
    cursorActive = true
    if (cursorCount <= 0) { cursorIndex = 0; return }
    cursorIndex = Math.max(0, Math.min(cursorCount - 1, cursorIndex + delta))
    scrollCursorIntoView()
  }

  function activateCursor() {
    if (!cursorActive) { cursorActive = true; return }
    if (cursorIndex === 0) sync.sendClipboard()
    else if (cursorIndex === 1) togglePaused()
    else if (cursorIndex === 2) sync.discover()
    else {
      var index = cursorIndex - actionCount
      if (index < 0 || index >= sync.devices.length) return
      var device = sync.devices[index]
      if (device.paired) setSelectedDevice(device.id)
      else if (device.reachable) sync.pair(device.id)
    }
  }

  function deleteCursorDevice() {
    var index = cursorIndex - actionCount
    if (index < 0 || index >= sync.devices.length) return
    var device = sync.devices[index]
    if (device.paired) requestUnpair(device)
  }

  function scrollCursorIntoView() {
    if (!panelFlick || cursorIndex < actionCount) return
    var row = deviceRepeater.itemAt(cursorIndex - actionCount)
    if (!row) return
    var top = row.mapToItem(deviceList, 0, 0).y + deviceList.y
    var bottom = top + row.height
    if (top < panelFlick.contentY) panelFlick.contentY = top
    else if (bottom > panelFlick.contentY + panelFlick.height) panelFlick.contentY = bottom - panelFlick.height
  }

  function copyInstallCommand() {
    Quickshell.execDetached(["bash", "-lc", "printf %s 'omarchy pkg add kdeconnect' | wl-copy"])
    sync.lastMessage = "Install command copied."
    sync.lastError = ""
  }

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    sync.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  onSettingsChanged: sync.settings = root.settings
  onCursorIndexChanged: scrollCursorIntoView()

  ClipboardSyncService {
    id: sync
    settings: root.settings
    onSelectionSuggested: function(deviceId) { root.setSelectedDevice(deviceId) }
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { sync.discover(); return "ok" }
    function send(): string { sync.sendClipboard(); return "ok" }
    function pause(): string { if (!sync.paused) root.togglePaused(); return "ok" }
    function resume(): string { if (sync.paused) root.togglePaused(); return "ok" }
    function status(): string { return sync.statusText }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barIcon
    active: sync.connected && !sync.paused
    tooltipText: sync.statusText
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.togglePaused()
      else if (buttonCode === Qt.MiddleButton) sync.discover()
      else root.toggle()
    }

  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(590))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.confirmOpen
      onMoveRequested: function(dx, dy) { root.moveCursor(dy !== 0 ? dy : dx) }
      onActivateRequested: root.activateCursor()
      onDeleteRequested: root.deleteCursorDevice()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "s" || text === "S") sync.sendClipboard()
        else if (text === "p" || text === "P") root.togglePaused()
        else if (text === "r" || text === "R") sync.discover()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: sync.selectedDevice ? String(sync.selectedDevice.name || "Clipboard Sync") : "Clipboard Sync"
            meta: sync.statusText
            detail: sync.mode === "manual" ? "MANUAL" : "EXPERIMENTAL"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: sync.dependencyState === "ready" ? 1.0 : 0.5
            iconComponent: Component {
              Text {
                text: root.barIcon
                color: sync.lastError !== "" ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Text {
            visible: root.hasStatusMessage
            width: parent.width
            textFormat: Text.PlainText
            text: sync.lastError !== "" ? sync.lastError : sync.lastMessage
            color: sync.lastError !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          CursorSurface {
            visible: sync.dependencyState === "missing"
            width: parent.width
            implicitHeight: missingColumn.implicitHeight + Style.space(20)
            foreground: root.foreground
            hasCursor: false

            Column {
              id: missingColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Text {
                width: parent.width
                text: "KDE Connect provides pairing, encryption, and the mobile apps. Install it explicitly, then retry."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }

              Row {
                spacing: Style.space(8)

                Text {
                  text: "omarchy pkg add kdeconnect"
                  color: root.foreground
                  font.family: "monospace"
                  font.pixelSize: Style.font.caption
                }

                PanelActionButton {
                  iconText: "󰆏"
                  tooltipText: "Copy install command"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.copyInstallCommand()
                }
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            ActionTile {
              width: (parent.width - Style.space(16)) / 3
              label: sync.operation === "send" ? "Sending…" : "Send"
              icon: "󰒊"
              enabled: sync.canSend
              current: root.cursorActive && root.cursorIndex === 0
              onHovered: root.cursorIndex = 0
              onChosen: sync.sendClipboard()
            }

            ActionTile {
              width: (parent.width - Style.space(16)) / 3
              label: sync.paused ? "Resume" : "Pause"
              icon: sync.paused ? "󰐊" : "󰏤"
              enabled: sync.dependencyState === "ready"
              current: root.cursorActive && root.cursorIndex === 1
              onHovered: root.cursorIndex = 1
              onChosen: root.togglePaused()
            }

            ActionTile {
              width: (parent.width - Style.space(16)) / 3
              label: sync.operation === "refresh" ? "Scanning…" : "Refresh"
              icon: "󰑐"
              enabled: !sync.busy
              current: root.cursorActive && root.cursorIndex === 2
              onHovered: root.cursorIndex = 2
              onChosen: sync.discover()
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          PanelSectionHeader {
            text: "DEVICES"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            visible: sync.dependencyState === "ready" && sync.devices.length === 0
            width: parent.width
            text: "No devices found. Keep both devices on the same local network and check that guest Wi-Fi isolation is disabled."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Column {
            id: deviceList
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              id: deviceRepeater
              model: sync.devices

              DeviceRow {
                required property var modelData
                required property int index
                width: deviceList.width
                device: modelData
                rowIndex: index
              }
            }
          }

          Text {
            width: parent.width
            text: sync.paused
              ? "Outbound clipboard sharing is paused. Pairing and incoming KDE Connect features remain available."
              : "Manual mode sends text only when you choose Send. Clipboard text may contain passwords, tokens, or personal information."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            visible: sync.kdeconnectVersion !== ""
            width: parent.width
            text: sync.kdeconnectVersion
            color: Qt.darker(root.dim, 1.2)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        z: 10
        opened: root.confirmOpen
        focus: root.confirmOpen
        message: "Unpair \"" + root.confirmDeviceName + "\"? It will no longer receive clipboard text."
        confirmText: "Unpair"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Keys.onPressed: function(event) {
          if (confirmDialog.handleKey(event)) event.accepted = true
        }
        onOpenedChanged: if (opened) Qt.callLater(function() { confirmDialog.forceActiveFocus() })
        onCanceled: root.cancelUnpair()
        onConfirmed: root.confirmUnpair()
      }
    }
  }

  component ActionTile: CursorSurface {
    id: actionTile
    property string label: ""
    property string icon: ""
    signal chosen()
    signal hovered()

    implicitHeight: Style.space(52)
    foreground: root.foreground
    hasCursor: current
    fill: root.hoverFill

    Row {
      anchors.centerIn: parent
      spacing: Style.space(7)

      Text {
        text: actionTile.icon
        color: actionTile.enabled ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }

      Text {
        text: actionTile.label
        color: actionTile.enabled ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: actionTile.enabled
      hoverEnabled: true
      cursorShape: actionTile.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: { root.cursorActive = true; actionTile.hovered() }
      onClicked: actionTile.chosen()
    }
  }

  component DeviceRow: CursorSurface {
    id: deviceRow
    property var device: null
    property int rowIndex: 0
    readonly property bool selected: device && String(device.id || "") === sync.selectedDeviceId
    readonly property string stateText: {
      if (!device) return "Unknown"
      if (device.paired && device.reachable) return selected ? "Paired · Connected · Selected" : "Paired · Connected"
      if (device.paired) return selected ? "Paired · Offline · Selected" : "Paired · Offline"
      if (device.reachable) return "Available to pair"
      return "Unavailable"
    }

    implicitHeight: deviceContent.implicitHeight + Style.spacing.rowPaddingX
    foreground: root.foreground
    hasCursor: root.cursorActive && root.cursorIndex === root.actionCount + rowIndex
    current: selected
    fill: root.hoverFill
    currentFill: root.selectedFill

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      onEntered: { root.cursorActive = true; root.cursorIndex = root.actionCount + deviceRow.rowIndex }
      onClicked: {
        if (deviceRow.device.paired) root.setSelectedDevice(deviceRow.device.id)
        else if (deviceRow.device.reachable) sync.pair(deviceRow.device.id)
      }
    }

    RowLayout {
      id: deviceContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(9)

      Text {
        text: deviceRow.device && deviceRow.device.reachable ? "󰄙" : "󰄚"
        color: deviceRow.device && deviceRow.device.reachable ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: deviceRow.device ? String(deviceRow.device.name || "Unknown device") : "Unknown device"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: deviceRow.selected
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: deviceRow.stateText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        visible: deviceRow.device && (deviceRow.device.paired || deviceRow.device.reachable)
        iconText: deviceRow.device && deviceRow.device.paired ? "󰌺" : "󰐕"
        tooltipText: deviceRow.device && deviceRow.device.paired ? "Unpair device" : "Pair device"
        foreground: root.foreground
        hoverColor: deviceRow.device && deviceRow.device.paired ? root.urgent : root.foreground
        fontFamily: root.fontFamily
        enabled: !sync.busy
        Layout.alignment: Qt.AlignVCenter
        onClicked: {
          if (deviceRow.device.paired) root.requestUnpair(deviceRow.device)
          else sync.pair(deviceRow.device.id)
        }
      }
    }
  }
}
