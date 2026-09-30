import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Per-monitor presentation for the shared Corsair VOID service.
BarWidget {
  id: root
  moduleName: "io.github.alexr1712.corsair-void"

  readonly property var service: bar && bar.shell
    ? bar.shell.serviceFor("io.github.alexr1712.corsair-void") : null
  readonly property bool showPercentage: settings.showPercentage !== false
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property var barIdentity: root
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true : false

  function pushSettings() {
    if (service && typeof service.applySettings === "function") service.applySettings(settings)
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = root.service
  }

  function syncInline() {
    pushSettings()
    injectPanel()
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  onServiceChanged: syncInline()
  onBarChanged: injectPanel()
  onSettingsChanged: syncInline()
  Component.onCompleted: syncInline()

  visible: !!service && (service.detected || service.sinkFound)
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

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
    target: "io.github.alexr1712.corsair-void"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): void { if (root.service) root.service.refresh() }
    function state(): string {
      if (!root.service) return JSON.stringify({ available: false })
      return JSON.stringify({
        available: true,
        detected: root.service.detected,
        connected: root.service.connected,
        wirelessStatus: root.service.wirelessStatus,
        batteryPercent: root.service.batteryPercent,
        charging: root.service.charging,
        sinkFound: root.service.sinkFound,
        volumePercent: root.service.volumePercent,
        muted: root.service.muted,
        defaultOutput: root.service.defaultOutput,
        sidetonePercent: root.service.sidetonePercent,
        hardwareWritable: root.service.hardwareWritable
      })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.service && root.service.connected && root.service.batteryPercent >= 0
      && root.service.batteryPercent <= 15
    text: {
      if (!root.service) return "󰋐"
      if (root.showPercentage && !vertical && root.service.connected
          && root.service.batteryPercent >= 0)
        return root.service.icon + " " + root.service.batteryPercent + "%"
      return root.service.icon
    }
    slotSize: Style.bar.iconSlot * (root.showPercentage && !vertical
      && root.service && root.service.connected ? 2 : 1)
    tooltipText: root.service
      ? "Corsair VOID Elite · " + root.service.statusLabel
        + (root.service.batteryPercent >= 0 ? " · " + root.service.batteryPercent + "%" : "")
      : "Corsair VOID Elite"

    onPressed: function(b) {
      if (!root.service) return
      if (b === Qt.RightButton && root.service.sinkFound) root.service.toggleMute()
      else if (b === Qt.MiddleButton) root.service.refresh()
      else root.togglePanel()
    }
    onWheelMoved: function(delta) {
      if (root.service && root.service.sinkFound)
        root.service.adjustVolume(delta > 0 ? 0.05 : -0.05)
    }
  }
}
