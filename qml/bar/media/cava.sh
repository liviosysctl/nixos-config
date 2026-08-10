#!/usr/bin/env bash
# Run cava against a copy of cava.conf with the input source substituted in.
#
#   cava.sh [source]
#
# cava takes its source from the config file and has no flag for it — `-p` is
# the only option it accepts — so pointing it at one application's stream means
# writing a config per source. cava.conf stays the single source of truth for
# everything else; only the one line is rewritten.
#
# `source` is a pipewire object name, which for an application stream is its
# node.name — "supersonic", "vesktop". Passing nothing, or `auto`, leaves the
# default sink's monitor, which is every sound the machine makes.
set -euo pipefail

src=${1:-auto}
here=$(dirname "$(readlink -f "$0")")

# One file per source, so switching players cannot race a running cava against
# a config that is being rewritten underneath it.
safe=$(printf '%s' "$src" | tr -c 'A-Za-z0-9._-' '_')
conf="${XDG_RUNTIME_DIR:-/tmp}/quickshell-cava-${safe}.conf"

sed "s|^source = .*|source = ${src}|" "$here/cava.conf" > "$conf"

exec cava -p "$conf"
