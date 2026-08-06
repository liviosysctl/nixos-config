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

    # Extra Qt modules or runtime binaries go per-app, e.g.:
    # lockscreen = {
    #   src = ../../qml/lockscreen;
    #   runtimeInputs = [ pkgs.procps pkgs.systemd ];
    # };
  };
in
{
  home.packages = lib.mapAttrsToList (name: args: qs.mkApp ({ inherit name; } // args)) apps ++ [
    (qs.mkDevRunner { inherit devRoot; })
  ];
}
