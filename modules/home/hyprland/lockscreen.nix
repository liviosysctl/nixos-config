{ pkgs, ... }:
let
  # Which locker runs. hyprlock is the default because it is the one this
  # setup has demonstrably locked with: hypridle drove it directly for months.
  #
  # qylock is off until it has been verified to actually paint. It takes the
  # ext-session-lock-v1 lock the moment it starts, so a qylock that dies during
  # startup leaves the session locked with nothing on screen to type into and
  # no way back short of killing the compositor from a TTY. A locker is the one
  # program where "it crashed" and "you are locked out" are the same event, so
  # it does not get to be the default on the strength of being on PATH.
  #
  # To try qylock: flip this to true, rebuild, and test it with the recipe in
  # the comment below BEFORE binding a key to it.
  useQylock = false;

  # Verifying qylock without locking yourself out:
  #
  #   1. Open a terminal and run:  qylock-lock 2>&1 | tee /tmp/qylock.log
  #   2. If the screen goes black, Ctrl+Alt+F2, log in, and:
  #        export XDG_RUNTIME_DIR=/run/user/$(id -u)
  #        hyprctl --instance 0 dispatch exit
  #   3. Read /tmp/qylock.log. QML import errors and missing Qt multimedia
  #      plugins both show up there.
  #
  # Never test it from the keybind: with no terminal attached there is nothing
  # holding stderr and the failure is silent, which is exactly how this
  # got shipped broken.

  locker = if useQylock then "qylock-lock" else "${pkgs.hyprlock}/bin/hyprlock";

  # The single entry point for "lock the screen now". keybinds.nix (SUPER+L),
  # wlogout.nix (the lock button) and hypridle.nix (idle timeout and
  # before_sleep) all call this one name.
  lockscreen = pkgs.writeShellScriptBin "lockscreen" ''
    set -u

    # One lock at a time. wlogout's suspend button and hypridle's
    # before_sleep_cmd can fire within the same second, and two clients racing
    # for ext-session-lock-v1 is a good way to end up with one that cannot be
    # dismissed.
    #
    # flock rather than a pgrep guard: the kernel releases it when fd 9 closes,
    # whatever takes the locker down. A pgrep guard would have to match a
    # process name, and qylock runs as `quickshell`, which is also what the bar
    # runs as.
    exec 9>"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lockscreen.lock"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      exit 0
    fi

    exec ${locker} "$@"
  '';
in
{
  home.packages = [ lockscreen ];
}
