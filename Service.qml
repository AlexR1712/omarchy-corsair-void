import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.Commons
import "Model.js" as Model

// One backend for every monitor. Battery warnings, polling and hardware
// writes happen here once; bar instances and panels are thin observers.
Item {
  id: root

  visible: false
  width: 0
  height: 0

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "corsair-void"
  readonly property string helperPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/corsair-void/bin/corsair-void-control"

  readonly property var defaultSettingValues: ({
    refreshIntervalSec: 15,
    showPercentage: true
  })
  property var settings: defaultSettingValues

  function applySettings(values) {
    var next = ({})
    for (var key in defaultSettingValues) next[key] = defaultSettingValues[key]
    var source = values || ({})
    for (var name in source) {
      if (source[name] === undefined || source[name] === null || name === "id") continue
      next[name] = source[name]
    }
    if (JSON.stringify(next) !== JSON.stringify(settings)) settings = next
  }

  readonly property int refreshIntervalSec: Math.max(5, Math.min(300,
    parseInt(String(settings.refreshIntervalSec), 10) || 15))

  // --------------------------------------------------------- PipeWire audio
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var sink: {
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i]
      if (!node || !node.isSink || node.isStream || !node.audio) continue
      var name = String(node.name || "").toLowerCase()
      if (name.indexOf("corsair") !== -1 && name.indexOf("void") !== -1) return node
    }
    return null
  }
  readonly property bool sinkFound: !!(sink && sink.audio)
  readonly property real outputVolume: sinkFound ? sink.audio.volume : 0
  readonly property int volumePercent: Math.round(outputVolume * 100)
  readonly property bool muted: sinkFound ? sink.audio.muted : false
  readonly property bool defaultOutput: !!(sink && Pipewire.defaultAudioSink === sink)

  function setOutputVolume(value) {
    if (!sinkFound) return
    sink.audio.volume = Math.max(0, Math.min(1, Number(value) || 0))
  }

  function adjustVolume(delta) {
    setOutputVolume(outputVolume + Number(delta || 0))
  }

  function toggleMute() {
    if (sinkFound) sink.audio.muted = !sink.audio.muted
  }

  function makeDefault() {
    if (!sink) return
    Pipewire.preferredDefaultAudioSink = sink
    if (sink.id !== undefined && sink.name) {
      Quickshell.execDetached([
        "omarchy-audio-output-set-default",
        String(sink.id),
        String(sink.name)
      ])
    }
  }

  // ----------------------------------------------------------- UPower data
  readonly property var powerDevices: UPower.devices ? UPower.devices.values : []
  readonly property var batteryDevice: {
    for (var i = 0; i < powerDevices.length; i++) {
      var device = powerDevices[i]
      if (!device) continue
      var nativePath = String(device.nativePath || "").toLowerCase()
      var model = String(device.model || "").toLowerCase()
      if (nativePath.indexOf("corsair-void") !== -1
          || (model.indexOf("corsair") !== -1 && model.indexOf("void") !== -1))
        return device
    }
    return null
  }
  readonly property bool batteryPresent: !!(batteryDevice && batteryDevice.isPresent)
  readonly property int rawBatteryPercent: batteryPresent
    ? Math.round(Number(batteryDevice.percentage || 0) * 100)
    : Model.number(deviceData.capacity, -1)
  readonly property bool charging: batteryDevice
    ? (batteryDevice.state === UPowerDeviceState.Charging
       || batteryDevice.state === UPowerDeviceState.FullyCharged)
    : deviceData.charging === "1"
  readonly property bool discharging: batteryDevice
    ? batteryDevice.state === UPowerDeviceState.Discharging
    : !charging

  // Keep the displayed percentage monotonic within a charge/discharge cycle.
  // The headset firmware can bounce between adjacent values while charging.
  property int batteryPercent: -1
  property string batteryMode: "unknown"

  function updateBattery(force) {
    var raw = rawBatteryPercent
    if (raw < 0) {
      batteryPercent = -1
      batteryMode = "unknown"
      checkLowBattery()
      return
    }
    var mode = charging ? "charging" : (discharging ? "discharging" : "idle")
    if (force === true || batteryPercent < 0 || batteryMode !== mode
        || Math.abs(raw - batteryPercent) > 10) {
      batteryPercent = raw
    } else if (mode === "charging") {
      batteryPercent = Math.max(batteryPercent, raw)
    } else if (mode === "discharging") {
      batteryPercent = Math.min(batteryPercent, raw)
    } else {
      batteryPercent = raw
    }
    batteryMode = mode
    checkLowBattery()
  }

  onBatteryDeviceChanged: Qt.callLater(function() { root.updateBattery(true) })

  Connections {
    target: root.batteryDevice
    ignoreUnknownSignals: true
    function onPercentageChanged() { root.updateBattery(false) }
    function onStateChanged() { root.updateBattery(false) }
    function onIsPresentChanged() { root.updateBattery(true) }
  }

  // ------------------------------------------------------ driver/sysfs data
  property var deviceData: ({})
  property string statusOutput: ""
  property string actionMessage: ""
  property int pendingSidetone: -1

  readonly property bool detected: deviceData.detected === "1"
  readonly property string wirelessStatus: String(deviceData.wireless_status || "unknown")
  readonly property bool connected: wirelessStatus === "connected"
    || (wirelessStatus === "unknown" && batteryPresent)
  readonly property bool hardwareWritable: deviceData.sidetone_writable === "1"
  readonly property int sidetonePercent: Math.max(0, Math.min(100,
    Model.number(deviceData.sidetone, 0)))
  readonly property string icon: Model.batteryIcon(Math.max(0, batteryPercent), charging, connected)
  readonly property string statusLabel: {
    if (!detected) return "Dongle not detected"
    if (!connected) return "Headset disconnected"
    if (charging) return "Charging"
    return "Wireless · connected"
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function queueSidetone(value) {
    pendingSidetone = Math.round(Math.max(0, Math.min(1, Number(value) || 0)) * 100)
    sidetoneDebounce.restart()
  }

  function setSidetonePreset(percent) {
    pendingSidetone = -1
    runHardwareAction(["sidetone", String(percent)], "Adjusting sidetone…")
  }

  function playAlert() {
    runHardwareAction(["alert"], "Playing headset alert…")
  }

  function runHardwareAction(args, message) {
    if (hardwareProcess.running) return
    actionMessage = message || "Applying…"
    hardwareProcess.command = [helperPath].concat(args)
    hardwareProcess.running = true
  }

  Process {
    id: statusProcess
    command: [root.helperPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.statusOutput = String(text || "")
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      root.deviceData = Model.parseStatus(root.statusOutput)
      root.updateBattery(root.batteryPercent < 0)
    }
  }

  Process {
    id: hardwareProcess
    onExited: function(exitCode) {
      root.actionMessage = exitCode === 0 ? "Applied" : "Could not apply that change"
      root.refresh()
      clearMessage.restart()
      if (root.pendingSidetone >= 0) sidetoneDebounce.restart()
    }
  }

  Timer {
    id: sidetoneDebounce
    interval: 120
    onTriggered: {
      if (hardwareProcess.running) { restart(); return }
      var value = root.pendingSidetone
      root.pendingSidetone = -1
      if (value >= 0) root.runHardwareAction(["sidetone", String(value)], "Adjusting sidetone…")
    }
  }

  Timer {
    id: clearMessage
    interval: 3000
    onTriggered: root.actionMessage = ""
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // --------------------------------------------------- persistent warnings
  PersistentProperties {
    id: persisted
    reloadableId: "corsair-void"
    property int notifiedBatteryBand: 0
  }

  function checkLowBattery() {
    if (!connected || charging || batteryPercent < 0) {
      if (!connected || charging) persisted.notifiedBatteryBand = 0
      return
    }
    var band = batteryPercent <= 10 ? 2 : (batteryPercent <= 20 ? 1 : 0)
    if (band === 0) {
      persisted.notifiedBatteryBand = 0
      return
    }
    if (band <= persisted.notifiedBatteryBand) return
    persisted.notifiedBatteryBand = band
    var command = omarchyPath !== ""
      ? omarchyPath + "/bin/omarchy-notification-send"
      : "omarchy-notification-send"
    Quickshell.execDetached([
      command, "--app-name", "Corsair VOID Elite",
      "-u", band === 2 ? "critical" : "normal",
      "Headset battery low", batteryPercent + "% remaining"
    ])
  }
}
