#!/usr/bin/env bash
# Network details quickshell's Networking service does not expose:
#
#   {
#     "interfaces": {"enp7s0": {"ip": "192.168.1.20/24", "gateway": "192.168.1.1"}},
#     "vpn": [{"interface": "tailscale0", "name": "Tailscale", "ip": "100.64.0.1"}]
#   }
#
# `interfaces` fills the address gap — the service exposes a device's MAC as
# `address` but not its IP, so NetworkCard reads it from here rather than
# parsing `ip` output in QML.
#
# `vpn` is here because the service models NetworkManager *devices*, and a
# tunnel is either not one at all (tailscale brings up its own tun behind
# NetworkManager's back) or is a device whose VPN-ness the service does not
# report. The interface list is the ground truth for "a tunnel is up";
# NetworkManager is consulted only to put a readable name on it.
set -euo pipefail

addrs=$(ip -j -4 addr show)
routes=$(ip -j -4 route show default)
# -d for linkinfo, which is what carries the tunnel kind.
links=$(ip -d -j link show)

# "ProtonVPN NL#3" reads better than "proton0". NetworkManager missing or not
# running is fine — naming just falls back to the interface.
connections=$(nmcli -t -e no -f NAME,TYPE,DEVICE connection show --active 2>/dev/null || true)

jq -n \
  --argjson addrs "$addrs" \
  --argjson routes "$routes" \
  --argjson links "$links" \
  --arg connections "$connections" '

# nmcli -t rows are NAME:TYPE:DEVICE. Only NAME can contain a colon, so split
# from the right rather than the left.
def rows:
  split("\n")
  | map(select(length > 0))
  | map(split(":") as $f | {name: ($f[0:-2] | join(":")), type: $f[-2], device: $f[-1]});

# Last resort, for tunnels NetworkManager does not own.
def friendly:
  if . == "tailscale0" then "Tailscale"
  elif startswith("wg") then "WireGuard"
  elif startswith("proton") then "ProtonVPN"
  else . end;

( [ $addrs[]
    | select(.addr_info | length > 0)
    | {key: .ifname, value: (.addr_info[0].local + "/" + (.addr_info[0].prefixlen | tostring))}
  ] | from_entries ) as $ips

# A wireguard link, or a tun proper — excluding tap, which shares the tun
# driver and is what libvirt hands to VMs.
| ( [ $links[]
      | select(.operstate != "DOWN")
      | select(.linkinfo.info_kind == "wireguard"
            or (.linkinfo.info_kind == "tun" and (.linkinfo.info_data.type // "tun") == "tun"))
      | .ifname
    ] ) as $tunnels

| ( $connections | rows | map(select(.type == "vpn" or .type == "wireguard")) ) as $vpns

# Kernel-level VPNs (wireguard, and anything else NetworkManager drives as a
# real device) name their own interface.
| ( $vpns | map(select(.device | IN($tunnels[]))) | map({key: .device, value: .name}) | from_entries ) as $owned

# Plugin VPNs (openvpn and friends) are stacked on a base connection, and
# nmcli reports that base device rather than the tun the plugin opens. So they
# have to be matched to an unclaimed tun positionally — exact for a single
# active VPN, best effort for several at once.
| ( $vpns | map(select(.type == "vpn" and (.device | IN($tunnels[]) | not))) ) as $stacked
| ( $tunnels | map(select($owned[.] == null and startswith("tun"))) ) as $unclaimed
| ( [$unclaimed, ($stacked | map(.name))]
    | transpose
    | map(select(.[0] != null and .[1] != null))
    | map({key: .[0], value: .[1]})
    | from_entries ) as $adopted

| {
    interfaces: ( [ $addrs[]
      | select(.addr_info | length > 0)
      | . as $if
      | {
          key: $if.ifname,
          value: {
            ip: ($if.addr_info[0].local + "/" + ($if.addr_info[0].prefixlen | tostring)),
            gateway: ([ $routes[] | select(.dev == $if.ifname) | .gateway ] | first)
          }
        }
    ] | from_entries ),

    vpn: (
      ( $tunnels | map({
          interface: .,
          name: ($owned[.] // $adopted[.] // friendly),
          ip: (($ips[.] // "") | split("/")[0])
        }) )
      # A VPN NetworkManager reports as up whose tun we could not find. Should
      # not happen, but it is better to show it unadorned than to drop it.
      + ( $stacked
          | map(select(.name | IN($adopted[])  | not))
          | map({interface: null, name: .name, ip: ""}) )
    )
  }
'
