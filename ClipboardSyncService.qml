import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var settings: ({})
  property string dependencyState: "checking"
  property string kdeconnectVersion: ""
  property var devices: []
  property string operation: "idle"
  property string lastMessage: ""
  property string lastError: ""
  property string lastErrorCode: ""
  property string observedAt: ""

  readonly property string selectedDeviceId: String(setting("selectedDeviceId", ""))
  readonly property bool paused: setting("paused", false) === true
  readonly property string mode: String(setting("mode", "manual"))
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 15, 5, 300)
  readonly property bool busy: adapterProcess.running
  readonly property var selectedDevice: deviceById(selectedDeviceId)
  readonly property bool connected: selectedDevice
    && selectedDevice.paired === true
    && selectedDevice.reachable === true
  readonly property bool canSend: dependencyState === "ready"
    && !paused
    && !busy
    && connected
  readonly property string statusText: {
    if (dependencyState === "checking") return "Checking dependencies"
    if (dependencyState === "missing") return "KDE Connect is required"
    if (dependencyState === "error") return "KDE Connect unavailable"
    if (paused) return "Outbound sharing paused"
    if (operation === "pair") return "Waiting for pairing confirmation"
    if (operation === "send") return "Sending clipboard"
    if (operation !== "idle") return "Updating device state"
    if (connected) return "Connected to " + String(selectedDevice.name || "phone")
    if (selectedDevice && selectedDevice.paired) return String(selectedDevice.name || "Phone") + " is offline"
    if (pairedDevices().length > 0) return "Choose a paired phone"
    if (devices.length > 0) return "Pair a phone"
    return "No phones found on this network"
  }

  property string _stdout: ""
  property string _stderr: ""
  property string _activeOperation: ""

  signal selectionSuggested(string deviceId)
  signal operationCompleted(string operation, bool ok, string message)

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var value = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(value)) value = fallback
    return Math.max(min, Math.min(max, value))
  }

  function adapterPath() {
    var value = String(Qt.resolvedUrl("scripts/clipboard-sync-adapter"))
    if (value.indexOf("file://") === 0) value = value.substring(7)
    try { return decodeURIComponent(value) } catch (error) { return value }
  }

  function deviceById(deviceId) {
    var id = String(deviceId || "")
    for (var i = 0; i < devices.length; i++) {
      if (String(devices[i].id || "") === id) return devices[i]
    }
    return null
  }

  function pairedDevices() {
    var result = []
    for (var i = 0; i < devices.length; i++) {
      if (devices[i].paired === true) result.push(devices[i])
    }
    return result
  }

  function normalizeSelection() {
    if (selectedDeviceId !== "" && deviceById(selectedDeviceId)) return
    var paired = pairedDevices()
    if (paired.length > 0) selectionSuggested(String(paired[0].id || ""))
    else if (selectedDeviceId !== "") selectionSuggested("")
  }

  function runAdapter(nextOperation, args) {
    if (busy) {
      lastErrorCode = "OPERATION_BUSY"
      lastError = "Another clipboard operation is still running."
      operationCompleted(nextOperation, false, lastError)
      return false
    }

    _stdout = ""
    _stderr = ""
    _activeOperation = nextOperation
    operation = nextOperation
    lastError = ""
    lastErrorCode = ""
    if (nextOperation !== "devices" && nextOperation !== "doctor") lastMessage = ""
    adapterProcess.command = [adapterPath(), nextOperation].concat(args || [])
    adapterProcess.running = true
    return true
  }

  function doctor() {
    dependencyState = "checking"
    runAdapter("doctor", [])
  }

  function refresh() {
    if (dependencyState !== "ready") {
      doctor()
      return
    }
    runAdapter("devices", [])
  }

  function discover() {
    if (dependencyState !== "ready") {
      doctor()
      return
    }
    runAdapter("refresh", [])
  }

  function pair(deviceId) {
    runAdapter("pair", ["--device-id", String(deviceId || "")])
  }

  function unpair(deviceId) {
    runAdapter("unpair", ["--device-id", String(deviceId || "")])
  }

  function sendClipboard() {
    if (paused) {
      lastErrorCode = "PAUSED"
      lastError = "Clipboard sharing is paused."
      operationCompleted("send", false, lastError)
      return
    }
    if (!selectedDevice || !selectedDevice.paired) {
      lastErrorCode = "DEVICE_UNPAIRED"
      lastError = "Select a paired phone before sending."
      operationCompleted("send", false, lastError)
      return
    }
    if (!selectedDevice.reachable) {
      lastErrorCode = "DEVICE_OFFLINE"
      lastError = String(selectedDevice.name || "The selected phone") + " is offline."
      operationCompleted("send", false, lastError)
      return
    }
    runAdapter("send", ["--device-id", selectedDeviceId])
  }

  function sanitizeMessage(value) {
    var text = String(value || "").replace(/[\x00-\x1f\x7f]+/g, " ").replace(/\s+/g, " ").trim()
    return text.length > 240 ? text.substring(0, 239) + "…" : text
  }

  function applyDevices(data) {
    devices = data && data.devices instanceof Array ? data.devices : []
    normalizeSelection()
  }

  function handleResponse(raw, exitCode) {
    var active = _activeOperation
    var parsed = null
    try {
      parsed = JSON.parse(String(raw || ""))
    } catch (error) {
      dependencyState = active === "doctor" ? "error" : dependencyState
      lastErrorCode = "INVALID_RESPONSE"
      lastError = "Clipboard Sync received an invalid adapter response."
      operation = "idle"
      operationCompleted(active, false, lastError)
      return
    }

    observedAt = String(parsed.observedAt || "")
    if (parsed.ok !== true || exitCode !== 0) {
      var errorData = parsed.error || ({})
      lastErrorCode = String(errorData.code || "INTERNAL_ERROR")
      lastError = sanitizeMessage(errorData.message || _stderr || "Clipboard Sync failed.")
      if (lastErrorCode === "DEPENDENCY_MISSING") dependencyState = "missing"
      else if (active === "doctor" || lastErrorCode === "DAEMON_UNAVAILABLE" || lastErrorCode === "UNSUPPORTED_VERSION") dependencyState = "error"
      operation = "idle"
      operationCompleted(active, false, lastError)
      return
    }

    var data = parsed.data || ({})
    if (active === "doctor") {
      dependencyState = "ready"
      kdeconnectVersion = String(data.kdeconnectVersion || "")
      lastMessage = "KDE Connect is ready."
    } else if (active === "devices" || active === "refresh") {
      applyDevices(data)
      lastMessage = devices.length > 0 ? "Device list updated." : "No devices found."
    } else if (active === "pair") {
      var paired = data.device || null
      if (paired && paired.id) selectionSuggested(String(paired.id))
      lastMessage = paired ? "Paired with " + String(paired.name || "device") + "." : "Pairing completed."
    } else if (active === "unpair") {
      if (String(data.deviceId || "") === selectedDeviceId) selectionSuggested("")
      lastMessage = "Device unpaired."
    } else if (active === "send") {
      lastMessage = "Sent to KDE Connect."
    }

    lastError = ""
    lastErrorCode = ""
    operation = "idle"
    operationCompleted(active, true, lastMessage)

    if (active === "doctor" || active === "pair" || active === "unpair")
      Qt.callLater(root.refresh)
  }

  Component.onCompleted: doctor()

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: root.dependencyState === "ready"
    onTriggered: if (!root.busy) root.refresh()
  }

  Process {
    id: adapterProcess

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._stdout = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._stderr = text
    }
    onExited: function(exitCode) {
      root.handleResponse(root._stdout, exitCode)
    }
  }
}
