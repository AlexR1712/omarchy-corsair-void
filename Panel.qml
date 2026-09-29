import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Popup presentation for the singleton service. No polling, notifications or
// audio state live here, so opening this on multiple monitors stays coherent.
Panel {
  id: root
  moduleName: "corsair-void"
  ipcTarget: "corsair-void"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color batteryColor: connected && batteryPercent <= 15 ? urgent : foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool detected: !!service && service.detected
  readonly property bool connected: !!service && service.connected
  readonly property bool charging: !!service && service.charging
  readonly property bool sinkFound: !!service && service.sinkFound
  readonly property bool muted: !!service && service.muted
  readonly property bool defaultOutput: !!service && service.defaultOutput
  readonly property bool hardwareWritable: !!service && service.hardwareWritable
  readonly property int batteryPercent: service ? service.batteryPercent : -1
  readonly property int volumePercent: service ? service.volumePercent : 0
  readonly property int sidetonePercent: service ? service.sidetonePercent : 0
  readonly property string icon: service ? service.icon : "󰋐"
  readonly property string statusLabel: service ? service.statusLabel : "Loading…"

  // ------------------------------------------------------------- lifecycle
  function open() {
    cursorActive = false
    cursorIndex = 0
    if (service) service.refresh()
    controller.show()
  }

  function openFromHotkey() { open() }
  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  // --------------------------------------------------------------- keyboard
  property int cursorIndex: 0
  property bool cursorActive: false
  readonly property int idxOutput: 0
  readonly property int idxMute: 1
  readonly property int idxDefault: 2
  readonly property int idxSidetone: 3
  readonly property int idxPresetStart: 4
  readonly property int idxPresetEnd: 8
  readonly property int idxAlert: 9

  function moveCursor(delta) {
    cursorActive = true
    cursorIndex = Math.max(0, Math.min(idxAlert, cursorIndex + delta))
  }

  function adjustFocused(delta) {
    if (!service) return
    if (cursorIndex === idxOutput) {
      service.adjustVolume(delta > 0 ? 0.05 : -0.05)
    } else if (cursorIndex === idxSidetone && hardwareWritable) {
      service.queueSidetone((sidetonePercent + (delta > 0 ? 5 : -5)) / 100)
    } else if (cursorIndex >= idxPresetStart && cursorIndex <= idxPresetEnd) {
      cursorIndex = Math.max(idxPresetStart, Math.min(idxPresetEnd,
        cursorIndex + (delta > 0 ? 1 : -1)))
    }
  }

  function activateCursor() {
    if (!service) return
    if (cursorIndex === idxOutput || cursorIndex === idxMute) service.toggleMute()
    else if (cursorIndex === idxDefault && !defaultOutput) service.makeDefault()
    else if (cursorIndex >= idxPresetStart && cursorIndex <= idxPresetEnd)
      service.setSidetonePreset((cursorIndex - idxPresetStart) * 25)
    else if (cursorIndex === idxAlert && hardwareWritable) service.playAlert()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390), Style.space(440))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(610))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dx !== 0) root.adjustFocused(dx)
        else if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: root.activateCursor()
      onTextKey: function(t) {
        if (!root.service) return
        if (t === "m" || t === "M") root.service.toggleMute()
        else if (t === "d" || t === "D") root.service.makeDefault()
        else if (t === "r" || t === "R") root.service.refresh()
        else if ((t === "a" || t === "A") && root.hardwareWritable) root.service.playAlert()
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
          id: contentColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          // --------------------------------------------------------- hero
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroText.implicitHeight,
              heroPercent.implicitHeight)

            Text {
              id: heroIcon
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.icon
              textFormat: Text.PlainText
              color: root.batteryColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }

            Column {
              id: heroText
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(13)
              anchors.right: heroPercent.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              Text {
                width: parent.width
                text: "VOID ELITE"
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                text: root.statusLabel.toUpperCase()
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.0
                elide: Text.ElideRight
              }
            }

            Text {
              id: heroPercent
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.connected && root.batteryPercent >= 0 ? root.batteryPercent + "%" : "—"
              textFormat: Text.PlainText
              color: root.batteryColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              font.bold: true
            }
          }

          Rectangle {
            visible: root.connected && root.batteryPercent >= 0
            width: parent.width
            height: Style.space(8)
            radius: height / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
            Rectangle {
              width: Math.max(parent.height, parent.width * root.batteryPercent / 100)
              height: parent.height
              radius: parent.radius
              color: root.batteryColor
              Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ------------------------------------------------------- output
          Column {
            width: parent.width
            spacing: Style.space(7)
            Item {
              width: parent.width
              implicitHeight: Math.max(outputHeader.implicitHeight, outputValue.implicitHeight)
              PanelSectionHeader {
                id: outputHeader
                anchors.left: parent.left
                text: "HEADSET OUTPUT"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              Text {
                id: outputValue
                anchors.right: parent.right
                text: root.muted ? "MUTED" : root.volumePercent + "%"
                color: root.muted ? root.urgent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            CursorSurface {
              width: parent.width
              height: outputSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.cursorIndex === root.idxOutput
              foreground: root.foreground
              outline: true
              PanelSlider {
                id: outputSlider
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                bar: root.bar
                minimum: 0
                maximum: 1
                step: 0.05
                value: root.volumePercent / 100
                enabled: root.sinkFound
                opacity: enabled ? 1 : 0.45
                onMoved: function(v) { if (root.service) root.service.setOutputVolume(v) }
                onRightClicked: if (root.service) root.service.toggleMute()
              }
              HoverHandler {
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.cursorIndex = root.idxOutput
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(7)
              Button {
                width: (parent.width - parent.spacing) / 2
                text: root.muted ? "Unmute" : "Mute"
                iconText: root.muted ? "󰖁" : "󰕾"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                hasCursor: root.cursorActive && root.cursorIndex === root.idxMute
                enabled: root.sinkFound
                onClicked: if (root.service) root.service.toggleMute()
                onHovered: function(h) { if (h) { root.cursorActive = true; root.cursorIndex = root.idxMute } }
              }
              Button {
                width: (parent.width - parent.spacing) / 2
                text: root.defaultOutput ? "Default output" : "Make default"
                iconText: root.defaultOutput ? "󰄬" : "󰓃"
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                active: root.defaultOutput
                hasCursor: root.cursorActive && root.cursorIndex === root.idxDefault
                enabled: root.sinkFound && !root.defaultOutput
                onClicked: if (root.service) root.service.makeDefault()
                onHovered: function(h) { if (h) { root.cursorActive = true; root.cursorIndex = root.idxDefault } }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ----------------------------------------------------- sidetone
          Column {
            width: parent.width
            spacing: Style.space(7)
            Item {
              width: parent.width
              implicitHeight: Math.max(sidetoneHeader.implicitHeight, sidetoneValue.implicitHeight)
              PanelSectionHeader {
                id: sidetoneHeader
                anchors.left: parent.left
                text: "SIDETONE"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              Text {
                id: sidetoneValue
                anchors.right: parent.right
                text: !root.hardwareWritable ? "UNAVAILABLE"
                  : (root.service && root.service.deviceData.sidetone === "-1"
                    ? "SET A LEVEL" : root.sidetonePercent + "%")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            CursorSurface {
              width: parent.width
              height: sidetoneSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.cursorIndex === root.idxSidetone
              foreground: root.foreground
              outline: true
              PanelSlider {
                id: sidetoneSlider
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                bar: root.bar
                minimum: 0
                maximum: 1
                step: 0.05
                value: root.sidetonePercent / 100
                enabled: root.hardwareWritable && root.connected
                opacity: enabled ? 1 : 0.45
                onMoved: function(v) { if (root.service) root.service.queueSidetone(v) }
              }
              HoverHandler {
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.cursorIndex = root.idxSidetone
                }
              }
            }

            Text {
              visible: !root.hardwareWritable
              width: parent.width
              text: "The root-owned Corsair udev rule is missing or inactive."
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              visible: root.hardwareWritable
              width: parent.width
              spacing: Style.space(7)
              Repeater {
                model: [0, 25, 50, 75, 100]
                Button {
                  required property var modelData
                  required property int index
                  width: (parent.width - parent.spacing * 4) / 5
                  text: String(modelData)
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  bordered: true
                  active: root.sidetonePercent === Number(modelData)
                  hasCursor: root.cursorActive && root.cursorIndex === root.idxPresetStart + index
                  onClicked: if (root.service) root.service.setSidetonePreset(Number(modelData))
                  onHovered: function(h) {
                    if (h) { root.cursorActive = true; root.cursorIndex = root.idxPresetStart + index }
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // -------------------------------------------------------- device
          Column {
            width: parent.width
            spacing: Style.space(7)
            PanelSectionHeader {
              text: "DEVICE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            InfoPair {
              label: "Wireless link"
              value: root.service ? root.service.wirelessStatus : "unknown"
            }
            InfoPair {
              label: "Microphone boom"
              value: root.service && root.service.deviceData.microphone_up === "1"
                ? "Up / muted" : "Down / active"
            }
            InfoPair {
              label: "Headset firmware"
              value: root.service ? (root.service.deviceData.headset_firmware || "—") : "—"
            }
            InfoPair {
              label: "Receiver firmware"
              value: root.service ? (root.service.deviceData.receiver_firmware || "—") : "—"
            }
            InfoPair { label: "Audio sink"; value: root.sinkFound ? "Available" : "Unavailable" }
            Button {
              visible: root.hardwareWritable
              width: parent.width
              text: "Play headset alert"
              iconText: "󰂞"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              hasCursor: root.cursorActive && root.cursorIndex === root.idxAlert
              enabled: root.connected
              onClicked: if (root.service) root.service.playAlert()
              onHovered: function(h) { if (h) { root.cursorActive = true; root.cursorIndex = root.idxAlert } }
            }
          }

          Text {
            visible: root.service && root.service.actionMessage !== ""
            width: parent.width
            text: root.service ? root.service.actionMessage : ""
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""
    width: parent.width
    spacing: Style.space(8)
    Text {
      text: parent.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Item {
      width: Math.max(0, parent.width - parent.children[0].implicitWidth
        - parent.children[2].implicitWidth - parent.spacing * 2)
      height: 1
    }
    Text {
      text: parent.value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
