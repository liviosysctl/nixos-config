#!/usr/bin/env bash
# Which connected outputs can actually do variable refresh, as one JSON object
# keyed by connector name:
#
#   {"DP-2":true,"DP-3":true}
#
# Hyprland reports whether VRR is *on* (`vrr` in `hyprctl monitors -j`) but not
# whether the display could do it at all, so DisplaysPage asks here before
# offering the toggle.
#
# The answer is the DRM connector property `vrr_capable`, which the driver sets
# from the display's own capabilities. It is not in sysfs — sysfs carries only
# connector_id, status, edid and modes — so it takes drm_info to read the
# property table, and connector_id to join that back to a name, because
# drm_info reports connectors by numeric id rather than as "DP-3".
#
# Absent property means unknown, not incapable: some drivers never expose it.
# Those outputs are simply left out, and the page leaves their toggle enabled
# rather than blocking a setting that might work. A display that genuinely
# cannot do VRR reports the property as 0 and lands here as false.
set -euo pipefail

# Connected connectors only, as `<connector_id> <name>` pairs. The directory is
# card1-DP-3 and the name Hyprland uses is DP-3, so the card prefix comes off.
sysfs=$(
  for dir in /sys/class/drm/card*-*/; do
    [ -r "$dir/connector_id" ] || continue
    [ "$(cat "$dir/status" 2>/dev/null)" = "connected" ] || continue
    name=$(basename "$dir")
    printf '%s %s\n' "$(cat "$dir/connector_id")" "${name#card*-}"
  done
)

# A GPU we cannot open is one we have no answer for, which is the same as no
# answer at all — the page treats an empty object as "ask nobody, allow all".
if ! drm=$(drm_info -j 2>/dev/null); then
  echo '{}'
  exit 0
fi

# Through stdin rather than --argjson: this dump runs to about a megabyte on a
# two-GPU machine, which is well past what will fit in a command line.
# printf is a bash builtin, so it never touches ARG_MAX.
printf '%s' "$drm" | jq --arg sysfs "$sysfs" '
  # id -> name, from the sysfs pairs.
  ($sysfs
    | split("\n")
    | map(select(length > 0) | split(" "))
    | map({ key: .[0], value: .[1] })
    | from_entries) as $names
  | [ .[].connectors[]
      # status 1 is DRM_MODE_CONNECTED. Writeback connectors report connected
      # too, but carry no vrr_capable, so the next filter drops them.
      | select(.status == 1)
      | select(.properties.vrr_capable != null)
      | select($names[.id | tostring] != null)
      | {
          key: $names[.id | tostring],
          value: (.properties.vrr_capable.raw_value == 1)
        }
    ] | from_entries
'
