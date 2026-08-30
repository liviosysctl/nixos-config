{
  inputs,
  options,
  lib,
  config,
  ...
}:
let

  # Blank the greeter's displays after this long without input. Any key or
  # mouse movement wakes them back up. 0 would disable idling entirely.
  greeterIdleSeconds = 300;

  # The SilentSDDM derivation with our theme/settings already applied. The
  # upstream module builds its GreeterEnvironment from this exact path; we have
  # to rebuild that string ourselves because we need two extra variables in it
  # and GreeterEnvironment is a single string that cannot merge two definitions.
  silent = config.programs.silentSDDM.package';
in
{
  imports = [
    inputs.qylock.nixosModules.default
    inputs.silentSDDM.nixosModules.default
  ];

  # Sets services.displayManager.sddm.theme = "silent", pulls the Qt runtime
  # deps into sddm.extraPackages and installs the theme fonts.
  programs.silentSDDM = {
    enable = true;

    # One of the presets in the theme's configs/ directory:
    # default, rei, ken, silvia, everforest, nord,
    # catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha
    theme = "nord";

    # Per-key overrides on top of the preset, e.g.:
    # settings = {
    #   "LoginScreen" = { background = "my-wallpaper.png"; };
    #   "LoginScreen.LoginArea.Avatar" = { shape = "circle"; };
    # };
    # Custom images go through programs.silentSDDM.backgrounds / .profileIcons.
  };

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
          # First two entries are what programs.silentSDDM sets by itself and
          # are required for the theme's QML components and virtual keyboard.
          # The last two are ours: ffmpeg backend for the animated backgrounds,
          # cursor lookup path for the greeter.
          GreeterEnvironment = lib.mkForce (builtins.concatStringsSep "," [
            "QML2_IMPORT_PATH=${silent}/share/sddm/themes/silent/components/"
            "QT_IM_MODULE=qtvirtualkeyboard"
            "QT_MEDIA_BACKEND=ffmpeg"
            "XCURSOR_PATH=/run/current-system/sw/share/icons"
          ]);
          # InputMethod is set to qtvirtualkeyboard by programs.silentSDDM.
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

    # Lockscreen only. The SDDM half of qylock is off -- SilentSDDM owns the
    # login screen now. `theme` below still selects the lockscreen theme.
    sddm.enable = false;

    theme = "Minecraft";

    # Puts `qylock-lock` on PATH with QS_THEME defaulted to the theme above.
    # Driven via the `lockscreen` wrapper in modules/home/hyprland/lockscreen.nix.
    quickshell.enable = true;
  };
}
