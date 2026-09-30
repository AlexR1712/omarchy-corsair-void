# Corsair VOID Elite for Omarchy

![Corsair VOID Elite widget showing battery, output volume, sidetone, and device status](preview.png)

An Omarchy bar widget for the Corsair VOID Elite Wireless headset.

## Requirements

- Omarchy 4 with the Quickshell-based shell
- Linux 6.13 or newer with the in-kernel `hid-corsair-void` driver
- UPower and PipeWire, included with Omarchy

## Install

```bash
omarchy plugin add https://github.com/AlexR1712/omarchy-corsair-void.git --enable
```

The plugin appears in the default bar section chosen by Omarchy. You can move it explicitly with:

```bash
omarchy bar move io.github.alexr1712.corsair-void --section right
```

### Upgrading from 2.x

Version 3 adopts the permanent marketplace ID. Replace the earlier local ID once:

```bash
omarchy plugin remove corsair-void --yes
omarchy plugin add https://github.com/AlexR1712/omarchy-corsair-void.git --enable
```

## Features

- Battery percentage and charge state through Quickshell's native UPower service
- Exact wireless connected/disconnected state from the in-kernel `hid-corsair-void` driver
- Persistent low-battery desktop notifications at 20% and 10%, emitted once across all monitors
- Native PipeWire output volume, mute, and default-output selection
- Hardware sidetone presets and slider
- Microphone boom position, headset/receiver firmware, and built-in alert test
- Configurable refresh interval and compact/percentage bar display

Left-click opens the panel, right-click toggles headset output mute, middle-click refreshes immediately, and the mouse wheel changes volume. The panel supports arrow-key navigation plus `M` for mute, `D` for default output, `R` for refresh, and `A` for the headset alert.

## Hardware permissions

Battery monitoring and audio controls work without extra privileges. The kernel exposes sidetone and the built-in alert as root-only sysfs controls. The bundled rule grants the Omarchy `wheel` group write access only to this headset driver's `set_sidetone` and `send_alert` attributes. The plugin itself contains no privilege-elevation path.

Install the root-owned rule once, then reconnect the wireless dongle. The
command writes the reviewed rule directly instead of asking `sudo` to read a
mutable file from the plugin checkout, and verifies the installed bytes:

```bash
sudo tee /etc/udev/rules.d/99-corsair-void-omarchy.rules >/dev/null <<'EOF'
# Permit Omarchy administrators to use the Corsair VOID kernel driver's
# write-only sidetone and alert controls. No HID device-node access is granted.
ACTION=="add|change", SUBSYSTEM=="hid", DRIVER=="hid-corsair-void", ATTR{sidetone_max}=="*", RUN+="/usr/bin/chgrp wheel /sys%p/set_sidetone", RUN+="/usr/bin/chmod 0620 /sys%p/set_sidetone", RUN+="/usr/bin/chgrp wheel /sys%p/send_alert", RUN+="/usr/bin/chmod 0620 /sys%p/send_alert"
EOF
printf '%s  %s\n' \
  b101f3b7959b62f6fbe5d38722c298a804717be6ad99da30ba63b4e260fcd332 \
  /etc/udev/rules.d/99-corsair-void-omarchy.rules | sha256sum -c -
sudo udevadm control --reload-rules
```

The panel will report hardware controls as available after the receiver is reconnected.

## Uninstall

Remove the plugin and its optional hardware-control permission:

```bash
omarchy plugin remove io.github.alexr1712.corsair-void --yes
sudo rm /etc/udev/rules.d/99-corsair-void-omarchy.rules
sudo udevadm control --reload-rules
```

## Controls

- Left click: open the panel
- Right click: mute or unmute the headset output
- Middle click: refresh hardware information
- Mouse wheel: change headset volume
- Keyboard: arrows navigate and adjust; `M` mutes, `D` selects the default output, `R` refreshes, and `A` plays the headset alert

For a machine-readable health check:

```bash
omarchy-shell io.github.alexr1712.corsair-void state
```

## License

MIT
