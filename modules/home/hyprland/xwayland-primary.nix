{ pkgs, lib, ... }:
let
  autoPrimaryScript = pkgs.writeShellScriptBin "hypr-auto-primary" ''
    # Wait for XWayland to report a connected output
    TIMEOUT=30
    ELAPSED=0
    while ! ${pkgs.xrandr}/bin/xrandr 2>/dev/null | grep -q " connected"; do
      sleep 0.5
      ELAPSED=$((ELAPSED + 1))
      if [ "$ELAPSED" -ge "$((TIMEOUT * 2))" ]; then
        echo "hypr-auto-primary: timed out waiting for XWayland" >&2
        exit 1
      fi
    done

    # Get the name of the monitor with ID 0 from hyprctl
    PRIMARY_NAME=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.id == 0) | .name')

    if [ -z "$PRIMARY_NAME" ]; then
      echo "hypr-auto-primary: no monitor with id 0 found" >&2
      exit 1
    fi

    # Try to match the Hyprland monitor name in xrandr output
    XRANDR_NAME=$(${pkgs.xrandr}/bin/xrandr --listmonitors | grep "$PRIMARY_NAME" | awk '{print $4}')

    if [ -z "$XRANDR_NAME" ]; then
      # Fallback: grab the first connected XWayland output
      XRANDR_NAME=$(${pkgs.xrandr}/bin/xrandr | grep " connected" | cut -d ' ' -f1 | head -n 1)
    fi

    if [ -n "$XRANDR_NAME" ]; then
      ${pkgs.xrandr}/bin/xrandr --output "$XRANDR_NAME" --primary
      echo "hypr-auto-primary: set $XRANDR_NAME as primary"
    else
      echo "hypr-auto-primary: no xrandr output found" >&2
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
