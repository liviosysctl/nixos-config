{ pkgs, lib, ... }:
# Mark the monitor at 0,0 as XWayland's primary output.
#
# X11 clients ask for "the primary output" and get one answer; without this
# they get whichever output XWayland happened to enumerate first, which is not
# stable across reboots. Games in particular use it to decide where to open.
#
# **Which 0,0?** Hyprland's, not XWayland's — and on a mixed-scale setup those
# are different monitors. Hyprland lays outputs out in *logical* pixels while
# XWayland uses native ones, so a 4K display at scale 1.5 occupies 2560×1440 in
# one space and 3840×2160 in the other, and the arrangement can come out in a
# different order:
#
#   Hyprland   DP-2 at 0,0      DP-3 at 2560,0
#   XWayland   DP-3 at +0+0     DP-2 at +3840+0
#
# Hyprland's is the one to follow: it is the space `monitors.lua` is written
# in and the space the shell's Displays panel shows. To follow XWayland's
# instead, drop the hyprctl call and pick the `xrandr --listmonitors` entry
# whose geometry ends in `+0+0`.
let
  autoPrimaryScript = pkgs.writeShellScriptBin "hypr-auto-primary" ''
    set -u

    XRANDR=${pkgs.xrandr}/bin/xrandr
    HYPRCTL=${pkgs.hyprland}/bin/hyprctl
    JQ=${pkgs.jq}/bin/jq

    # The monitor Hyprland has at the origin. Not `id == 0`: that is the order
    # Hyprland happened to assign ids in, which follows plug order rather than
    # layout, and drifts when a display is unplugged and reattached. It agrees
    # with the origin often enough to look correct and then quietly stops.
    origin_monitor() {
      "$HYPRCTL" monitors -j 2>/dev/null \
        | "$JQ" -r 'first(.[] | select(.x == 0 and .y == 0) | .name) // empty'
    }

    # XWayland names its outputs after the real ones, so the name carries
    # across. It does not come up at the same time as Hyprland, though.
    known_to_xwayland() {
      "$XRANDR" 2>/dev/null | grep -q "^$1 connected"
    }

    # Poll rather than sleep a fixed amount. The old version waited for *any*
    # connected output, which returns the moment the first display appears —
    # on a two-monitor setup that is regularly before the second one exists,
    # and always before Hyprland has finished applying monitors.lua. So the
    # wait is for the specific answer we are about to act on.
    TARGET=""
    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      CANDIDATE=$(origin_monitor)
      if [ -n "$CANDIDATE" ] && known_to_xwayland "$CANDIDATE"; then
        TARGET="$CANDIDATE"
        break
      fi
      sleep 0.5
    done

    if [ -z "$TARGET" ]; then
      echo "hypr-auto-primary: no monitor at 0,0 visible to XWayland after 30s" >&2
      exit 1
    fi

    # Settle. Hitting the condition is not the same as the layout being final:
    # a second display can still attach a beat later and take the origin. Look
    # again, and believe the second answer.
    sleep 2
    SETTLED=$(origin_monitor)
    if [ -n "$SETTLED" ] && [ "$SETTLED" != "$TARGET" ] && known_to_xwayland "$SETTLED"; then
      echo "hypr-auto-primary: origin moved to $SETTLED while waiting"
      TARGET="$SETTLED"
    fi

    # xrandr always warns that it is talking to an Xwayland server. That is
    # expected and says nothing about whether this worked, so it is held back
    # and only shown if the call actually fails.
    if OUTPUT=$("$XRANDR" --output "$TARGET" --primary 2>&1); then
      echo "hypr-auto-primary: $TARGET is primary"
    else
      echo "hypr-auto-primary: xrandr failed for $TARGET" >&2
      echo "$OUTPUT" >&2
      exit 1
    fi
  '';
in
{
  home.packages = [ autoPrimaryScript ];

  wayland.windowManager.hyprland.settings.on = [
    {
      _args = [
        "hyprland.start"
        (lib.generators.mkLuaInline ''
          function()
            hl.exec_cmd([[${autoPrimaryScript}/bin/hypr-auto-primary]])
          end'')
      ];
    }
  ];
}
