{ lib, pkgs, ... }:

let
  qs = import ../../lib/quickshell.nix { inherit pkgs lib; };

  # Where the repo is checked out. Only `qs-dev` uses this — the packaged
  # apps below read from the store. Override per-invocation with QML_SRC_ROOT
  # if your checkout lives somewhere else.
  devRoot = "$HOME/nixos-config/qml";

  # Each entry becomes a `qs-<name>` command reading ../../qml/<name>/shell.qml.
  # Adding a shell = one directory under qml/ plus one line here.
  apps = {
    example-panel = {
      src = ../../qml/example-panel;
    };

    bar = {
      src = ../../qml/bar;
      runtimeInputs = [
        # media/: the visualiser shells out to cava.
        pkgs.cava
        # network/: netinfo.sh fills in the IPv4 details quickshell's
        # Networking service does not expose, and detects active VPN tunnels
        # from the interface list. nmcli only names them — the script runs
        # fine without it, so this is not load-bearing for detection.
        pkgs.bash
        pkgs.jq
        pkgs.iproute2
        pkgs.networkmanager
        # bluetooth/: btctl.sh covers pair and forget, which the Bluetooth
        # service exposes no method for.
        pkgs.bluez
        # settings/: Displays applies monitor changes with `hyprctl eval`.
        # It resolved from the ambient PATH before, which holds right up until
        # the shell is started from somewhere that has not sourced the user
        # profile — a systemd unit, say. Same derivation the compositor itself
        # comes from, so this adds an edge and no closure.
        pkgs.hyprland
        # settings/displays/: vrrcap.sh reads the DRM `vrr_capable` connector
        # property to work out which outputs can do adaptive sync. Neither
        # sysfs nor Hyprland's IPC exposes it, and drm_info is the smallest
        # thing that reads the property table. Needs membership of the `video`
        # group, which is what makes /dev/dri/card* openable.
        pkgs.drm_info
        # settings/wallpaper/: applying is a restart of the slideshow unit,
        # and "next wallpaper" is a SIGUSR1 to it. See
        # modules/home/hyprland/wallpaper-slideshow.nix for why the shell asks
        # systemd rather than driving awww itself.
        #
        # session/: also systemd-inhibit, which is what holds the idle lock.
        pkgs.systemd
        # session/: the idle lock's payload is `cat` on a pipe, so that the
        # lock dies with the shell rather than outliving it. See Idle.qml —
        # this is load-bearing, not incidental.
        pkgs.coreutils
        # session/: the nix glyph opens `session-menu`, the wlogout wrapper
        # from modules/home/wlogout.nix. That is a home.packages entry rather
        # than something referable from here, so it resolves off the ambient
        # PATH — wlogout stays listed because it is what the wrapper execs.
        pkgs.wlogout
        # system/: the cpu and memory readouts open btop in $TERMINAL, which
        # modules/home/default.nix exports from `vars.terminal`. The readings
        # themselves are /proc and need nothing.
        pkgs.btop
        pkgs.kitty
      ];
    };

    # Extra Qt modules or runtime binaries go per-app, e.g.:
    # lockscreen = {
    #   src = ../../qml/lockscreen;
    #   runtimeInputs = [ pkgs.procps pkgs.systemd ];
    # };
  };

  # Bound so the bar's store path can be named again below, for its unit.
  built = lib.mapAttrs (name: args: qs.mkApp ({ inherit name; } // args)) apps;
in
{
  home.packages = lib.attrValues built ++ [
    # One dev runner serves every shell, so it needs the union of their
    # runtime deps rather than any single app's.
    (qs.mkDevRunner {
      inherit devRoot;
      runtimeInputs = lib.concatMap (args: args.runtimeInputs or [ ]) (lib.attrValues apps);
    })
  ];

  # The bar, as a session service. This replaces the waybar unit that
  # home-manager's own module used to provide, and is arranged the same way:
  # pulled in by graphical-session.target, and also started by name from
  # hyprland's autostart list.
  #
  # The environment is not this unit's problem. uwsm runs the session —
  # wayland-wm@hyprland.desktop.service is what reaches
  # graphical-session.target — so WAYLAND_DISPLAY and
  # HYPRLAND_INSTANCE_SIGNATURE are already in the user manager by the time
  # anything wanted by that target starts.
  systemd.user.services.qs-bar = {
    Unit = {
      Description = "Quickshell bar";
      After = "graphical-session.target";
      PartOf = "graphical-session.target";
    };
    Service = {
      ExecStart = "${built.bar}/bin/qs-bar";
      # A bar that dies takes the clock, the tray and the settings panel with
      # it, and there is nothing else to get them back from.
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
