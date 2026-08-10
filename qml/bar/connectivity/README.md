# Connectivity

One panel for everything that connects — wired, Wi-Fi and bluetooth share a
single orbit, and tabs along the bottom swap which one it shows. After the
layout in [ilyamiro's config](https://github.com/ilyamiro/nixos-configuration),
minus the animated lines running from each node back to the core.

Used from `../shell.qml`, which imports this directory
(`import "connectivity"`):

```qml
Net { id: netState }                                          // shared, once
Bt  { id: btState }
...
ConnectivityWidget { theme: root; net: netState; bt: btState } // per bar
```

`Net` and `Bt` sit at `ShellRoot` level so every screen agrees on state and
only one scan of each kind runs. `ConnectivityWidget` is per bar, which is
what makes the panel open only on the monitor you clicked.

## Files

| File | What it does |
| --- | --- |
| `Net.qml` | NetworkManager state: primary device, glyph, access points, addresses |
| `Bt.qml` | BlueZ state: adapter, ordered device list, glyph mapping, pair/forget |
| `Orbit.qml` | Ring geometry — where each pill goes and how big it can be |
| `ConnectivityCard.qml` | The panel: core, orbit, tabs |
| `ConnectivityWidget.qml` | The two bar glyphs and the shared `PopupWindow` |
| `netinfo.sh` | IPv4 address and gateway per interface, plus active VPN tunnels, as JSON |
| `btctl.sh` | `pair` and `forget`, the two actions BlueZ's service has no method for |

## The two glyphs, one panel

The bar shows a network glyph and a bluetooth glyph side by side. Clicking
either opens the same panel on that glyph's tab — the network glyph opens
Ethernet or Wi-Fi depending on what is carrying traffic. Clicking the glyph
whose tab is already showing closes the panel.

Tabs for hardware that does not exist stay hidden, and each glyph hides itself
when its service reports nothing.

There is deliberately **no automatic tab fallback**. Both services report
nothing for the first seconds after start, so anything that "corrects" an
unavailable mode during that window lands on whichever service answered
first — which had the panel opening on Bluetooth while a perfectly good Wi-Fi
device was still being enumerated. The widget picks the tab when it opens,
by which point the services have answered.

## Ring geometry

This is the part that took the most care, so it lives in `Orbit.qml` on its
own.

Pills are spaced evenly by angle around an ellipse — an ellipse rather than a
circle because the panel is wider than the orbit is tall. Every other pill is
pulled slightly inward (`zigzag`), which is purely cosmetic and gives the
staggered look of the original.

Positions are **computed, never animated**. Nothing rotates: a ring of moving
targets is miserable to click. Only the decorative rings breathe, and only
while scanning.

**Sizing is solved, not guessed.** Closed-form spacing rules were tried first
and every one of them was wrong somewhere — on an ellipse the arc between
neighbours is not uniform, and the zigzag makes the tightest pair depend on
parity as well as on count. So `Orbit.collides()` tests the actual rectangles
and `Orbit.fit()` binary-searches the largest scale that clears everything,
including the core. `Orbit.capacity()` then reports how many will actually go
on the ring; anything past that is counted in the footer rather than dropped
silently.

At the current size the ring takes 12 pills at full scale and shrinks them
from there, down to a floor where the labels stop being legible. To change
how many fit, change the panel's `implicitWidth` / `implicitHeight` — the
solver adapts, and `minScale` decides where it gives up.

**Nothing is sorted by signal strength.** Strength jitters constantly, and
this list drives ring positions — sorting by it would have pills trading
places under the cursor, and would rebuild the array on every RSSI update.
Order is connected, then saved/paired, then alphabetical. Strength still
picks each pill's glyph; it just does not pick where the pill sits.

## What each tab shows

| Tab | Core | Orbit |
| --- | --- | --- |
| Ethernet | Interface name, link state | Address, gateway, link speed, MAC |
| Wi-Fi | Radio toggle, current SSID | Access points |
| Bluetooth | Adapter toggle, connected count | Devices |

Wired has nothing to pick between, so it orbits its own connection details
instead of a list.

## VPN

A badge in the top-right corner of the panel names the tunnel whenever one is
up, and is absent otherwise. It sits outside the ring rather than on it: a
tunnel is machine-wide, not a property of the tab you happen to be looking at.
It shows on Ethernet and Wi-Fi, and is hidden on Bluetooth where it would read
as a claim about the adapter. The corner is free by construction — pills are
centred on the ellipse, so nothing reaches it at any count or scale.

**Detection is interface-driven, not NetworkManager-driven.** The service
models NetworkManager devices, and a tunnel is often not one: tailscale brings
up its own `tun` without NetworkManager ever seeing it. So `netinfo.sh` reads
the link list and treats any up `wireguard` link, or `tun` proper, as a VPN.
`tap` is excluded — it shares the tun driver and is what libvirt hands to VMs.

NetworkManager is consulted only to put a readable name on what was found:

| Kind | Named by |
| --- | --- |
| WireGuard via NetworkManager | the connection name — its device *is* the tunnel |
| Plugin VPNs (openvpn and friends) | the connection name, matched to an unclaimed `tun` |
| Anything else (tailscale, hand-rolled `wg`) | `tailscale0` → Tailscale, `wg*` → WireGuard, else the interface name |

The plugin case needs the matching because nmcli reports the *base* device for
a stacked VPN connection, not the tun the plugin opens. That is exact for one
active VPN and best-effort for several at once.

Wi-Fi passphrase entry happens **in the core** — it turns into the input
while a secured unknown network is pending, which is where the original put
it too, and avoids trying to expand a pill on a ring.

## Interaction

| Where | Action |
| --- | --- |
| Bar glyph | Open the panel on that tab, or close it if already showing |
| Core | Toggle the radio / adapter (Ethernet has no switch) |
| Pill | Left-click: connect, disconnect, or pair |
| Pill | Right-click: forget (saved networks and paired devices only) |
| Advanced | Opens the manager for the current tab |

## What is native and what is not

Both services are property-driven; the shell-outs cover the gaps.

| Action | How |
| --- | --- |
| Wi-Fi radio, scanning, connect, disconnect, forget | `Networking` / `Network` |
| BT power, discovery, connect, disconnect, trust | `Bluetooth` adapter / device properties |
| IPv4 address and gateway | `netinfo.sh` — `device.address` is the **MAC** |
| VPN tunnels | `netinfo.sh` — tunnels are often not NetworkManager devices |
| BT pair and forget | `btctl.sh` — no method exists for either |

## Limitations

- **Pairing uses bluetoothctl's default `NoInputNoOutput` agent**, which
  covers "just works" devices. PIN or numeric-comparison pairing needs a real
  agent — that is what Advanced is for.
- **A rfkill-blocked adapter cannot be powered on from the panel.** quickshell
  logs `Cannot enable adapter because it is blocked by rfkill`. Clear it with
  `rfkill unblock bluetooth`.
- **Enterprise and WEP Wi-Fi** need a profile rather than a passphrase, and
  are sent to Advanced.

## Requirements

- NetworkManager and BlueZ running.
- `ip`, `jq`, `bash`, `bluetoothctl` on `PATH` — provided by the bar app's
  `runtimeInputs` in `modules/home/qml.nix`. `nmcli` is there too, but only
  names VPN tunnels; detection works without it.
- `gazelle` (in kitty) and `blueman-manager` for Advanced, matching the
  waybar modules' `on-click`.
