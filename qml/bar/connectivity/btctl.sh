#!/usr/bin/env bash
# The two bluetooth actions quickshell's Bluetooth service does not expose.
# Everything else — adapter power, discovery, connect, disconnect, trust — is
# a writable property on the adapter or device object and is done in QML.
#
#   btctl.sh pair <address>     pair, then trust so it reconnects on its own
#   btctl.sh forget <address>   drop the pairing entirely
#
# Pairing runs under bluetoothctl's default NoInputNoOutput agent, which
# covers "just works" devices — headsets, mice, most speakers. Anything that
# wants a PIN or a numeric comparison needs a real agent; those go to blueman
# via the card's Advanced button.
set -euo pipefail

action=${1:?usage: btctl.sh <pair|forget> <address>}
address=${2:?usage: btctl.sh <pair|forget> <address>}

case "$action" in
pair)
    bluetoothctl --timeout 30 pair "$address"
    bluetoothctl trust "$address"
    ;;
forget)
    bluetoothctl remove "$address"
    ;;
*)
    echo "btctl.sh: unknown action '$action'" >&2
    exit 2
    ;;
esac
