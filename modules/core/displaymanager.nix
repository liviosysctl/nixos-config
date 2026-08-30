{
  inputs,
  options,
  pkgs,
  ...
}:
let

  # Blank the greeter's displays after this long without input. Any key or
  # mouse movement wakes them back up. 0 would disable idling entirely.
  greeterIdleSeconds = 300;
in
{
  imports = [ inputs.qylock.nixosModules.default ];

  services.displayManager = {
    defaultSession = "hyprland-uwsm";

    sddm = {
      enable = true;
      wayland.enable = true;

      # SDDM has no idle handling of its own, so it comes from the greeter's
      # compositor (Weston). Take nixpkgs' own command as the base -- it carries
      # the keymap/libinput settings generated from our NixOS options -- and only
      # append the idle timeout, so a nixpkgs bump doesn't leave us on a stale copy.
      wayland.compositorCommand =
        options.services.displayManager.sddm.wayland.compositorCommand.default
        + " --idle-time=${toString greeterIdleSeconds}";

      settings = {
        General = {
          GreeterEnvironment = builtins.concatStringsSep "," [
            "QT_MEDIA_BACKEND=ffmpeg"
            "XCURSOR_PATH=/run/current-system/sw/share/icons"
          ];
          InputMethod = "";
        };

        Theme = {
          CursorTheme = "MacOSX-Cursor";
          CursorSize = 24;
        };
      };
    };
  };


  xdg.icons.fallbackCursorThemes = [ "MacOSX-Cursor" ];

  programs.qylock = {
    enable = true;
    theme = "Minecraft";

    # Puts `qylock-lock` on PATH with QS_THEME defaulted to the theme above.
    # Driven via the `lockscreen` wrapper in modules/home/hyprland/lockscreen.nix.
    quickshell.enable = true;
  };
}
