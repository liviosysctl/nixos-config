{ pkgs, ... }:
{
  home.packages = with pkgs; [
    jq
  ];

  wayland.windowManager.hyprland.settings.exec-once = [
    # Environment setup (should be first)
    "systemctl --user import-environment PATH"
    "systemctl --user import-environment HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    "hash dbus-update-activation-environment 2>/dev/null &"
    "dbus-update-activation-environment --systemd &"

    # Services
    "systemctl --user start waybar"

    # UI Components
    "awww-daemon"
    "eww daemon"

    # Cursor
    "hyprctl setcursor WiiPointer 24"
  ];
}
