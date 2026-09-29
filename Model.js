.pragma library

function parseStatus(raw) {
  var result = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var pos = lines[i].indexOf("=")
    if (pos <= 0) continue
    result[lines[i].substring(0, pos)] = lines[i].substring(pos + 1)
  }
  return result
}

function number(value, fallback) {
  var parsed = parseInt(String(value), 10)
  return isFinite(parsed) ? parsed : fallback
}

function batteryIcon(percent, charging, connected) {
  if (!connected) return "󰋐"
  if (charging) return "󰂄"
  if (percent >= 90) return "󰁹"
  if (percent >= 70) return "󰂀"
  if (percent >= 50) return "󰁾"
  if (percent >= 30) return "󰁼"
  if (percent >= 10) return "󰁺"
  return "󰂎"
}

function statusLabel(data) {
  if (data.detected !== "1") return "Dongle not detected"
  if (data.wireless_status === "disconnected") return "Headset disconnected"
  if (data.wireless_status !== "connected" && data.present !== "1") return "Headset unavailable"
  if (data.charging === "1") return "Charging"
  return "Wireless · connected"
}
