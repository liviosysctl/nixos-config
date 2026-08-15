{ lib, pkgs, ... }:
let
  # `exec-once = "..."` has no direct equivalent; startup commands now hang off
  # the hyprland.start event, so the whole list becomes one Lua function.
  startupCommands = [
    # Environment setup (should be first)
    "systemctl --user import-environment PATH"
    "systemctl --user import-environment HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    "hash dbus-update-activation-environment 2>/dev/null &"
    "dbus-update-activation-environment --systemd &"

    # Services
    # The bar. Its unit is defined in modules/home/qml.nix and is already
    # wanted by graphical-session.target, so this is belt-and-braces rather
    # than the only thing bringing it up — but it is what makes "hyprland
    # starts the bar" true where you would go looking for it.
    "systemctl --user start qs-bar"

    # UI Components
    "awww-daemon"
    "eww daemon"

    # Cursor
    "hyprctl setcursor WiiPointer 24"
  ];

  # Long-bracket strings so the commands need no escaping.
  execLines = lib.concatMapStringsSep "\n" (cmd: "  hl.exec_cmd([[${cmd}]])") startupCommands;
in
{
  home.packages = with pkgs; [
    jq
  ];

  wayland.windowManager.hyprland.settings.on = [
    {
      _args = [
        "hyprland.start"
        (lib.generators.mkLuaInline ''
          function()
          ${execLines}
          end'')
      ];
    }
  ];
}
