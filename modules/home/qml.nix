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
        # settings/: vrrcap.sh reads the DRM `vrr_capable` connector property
        # to work out which outputs can do adaptive sync. Neither sysfs nor
        # Hyprland's IPC exposes it, and drm_info is the smallest thing that
        # reads the property table. Needs membership of the `video` group,
        # which is what makes /dev/dri/card* openable.
        pkgs.drm_info
      ];
    };

    # Extra Qt modules or runtime binaries go per-app, e.g.:
    # lockscreen = {
    #   src = ../../qml/lockscreen;
    #   runtimeInputs = [ pkgs.procps pkgs.systemd ];
    # };
  };
in
{
  home.packages = lib.mapAttrsToList (name: args: qs.mkApp ({ inherit name; } // args)) apps ++ [
    # One dev runner serves every shell, so it needs the union of their
    # runtime deps rather than any single app's.
    (qs.mkDevRunner {
      inherit devRoot;
      runtimeInputs = lib.concatMap (args: args.runtimeInputs or [ ]) (lib.attrValues apps);
    })
  ];
}
