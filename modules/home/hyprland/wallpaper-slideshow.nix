{ pkgs, ... }:
# The wallpaper: what is displayed, and when it changes.
#
# The settings live in ~/.config/quickshell/wallpaper.json, written by the
# shell's Wallpaper section (qml/bar/settings/wallpaper). This script reads
# that file on start and nothing else drives it, so "apply" over there is a
# `systemctl --user restart` and the two sides never have to agree on an IPC.
#
# It publishes the path it is about to display to
# ~/.local/state/quickshell/wallpaper. That is what lets the bar tint itself
# from the wallpaper — see qml/bar/theme/Palette.qml — and it is written
# *before* awww is called, so the bar's cross-fade and the wallpaper's
# transition are the same movement rather than one chasing the other.
#
# Why this stays a systemd unit rather than moving into quickshell, which
# would make the whole state file unnecessary: the shell is started by hand,
# not autostarted. A wallpaper that only existed while quickshell ran would be
# a wallpaper that usually did not.
#
# Why awww and not something else. awww is swww under nixpkgs' new name, and
# it is still the only wayland wallpaper daemon with real transitions —
# per-transition type, duration, frame rate and a bezier curve, all rendered
# by the daemon. hyprpaper and swaybg cut with no transition at all; wpaperd
# has a fade and no control over it; mpvpaper is a video player. There is
# nothing better to move to, so the improvement here is in using what it
# already offers: `fade` on a tuned curve, at the panel's frame rate, instead
# of the default `simple` (which ignores --transition-duration entirely and
# steps by rgb value instead).
let
  # Material's standard easing. awww's own default (.54,0,.34,.99) accelerates
  # late and finishes abruptly, which is what makes the stock transition read
  # as a wipe even when it is a fade.
  bezier = ".4,0,.2,1";

  # Kept in step with the browser's filter in
  # qml/bar/settings/wallpaper/PathBrowser.qml — a directory whose images the
  # panel shows but this skips would be a confusing thing to hand someone.
  findExpr = ''\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" \)'';

  wallpaper-slideshow = pkgs.writeShellScriptBin "wallpaper-slideshow" ''
    set -u

    CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/wallpaper.json"
    STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
    STATE="$STATE_DIR/wallpaper"

    ${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR"

    # ── Config ───────────────────────────────────────────────────────────
    # One jq call per key rather than one eval of a generated assignment
    # block: a wallpaper path is arbitrary user text, and eval'ing it is how
    # a filename with a backtick in it becomes a shell injection.
    #
    # `has($k)` rather than jq's `//` operator, because `false // fallback`
    # takes the fallback — which would make `"shuffle": false` unsettable.
    cfg() {
      local key="$1" fallback="$2" value=""
      if [ -f "$CONFIG" ]; then
        value=$(${pkgs.jq}/bin/jq -r --arg k "$key" \
          'if has($k) and .[$k] != null then .[$k] else empty end' \
          "$CONFIG" 2>/dev/null) || value=""
      fi
      if [ -n "$value" ]; then printf '%s' "$value"; else printf '%s' "$fallback"; fi
    }

    MODE=$(cfg mode slideshow)
    IMAGE=$(cfg image "")
    DIR=$(cfg directory "$HOME/pictures/wallpaper/slideshow")
    INTERVAL=$(cfg intervalSeconds 600)
    SHUFFLE=$(cfg shuffle true)
    TRANSITION=$(cfg transition fade)
    DURATION=$(cfg transitionDuration 1.5)
    FPS=$(cfg transitionFps 120)

    # ── Interruptible waiting ────────────────────────────────────────────
    # SIGUSR1 is the panel's "next wallpaper" button. A restart would work
    # too, but it would re-display the current image before moving on — two
    # transitions where the user asked for one.
    SKIP=0
    trap 'SKIP=1' USR1

    nap() {
      # Backgrounded and waited on, because a foreground `sleep` is not
      # interrupted by a trapped signal until it finishes on its own — which
      # for the default interval means the button appears dead for ten
      # minutes.
      sleep "$1" &
      local pid=$!
      wait "$pid" 2>/dev/null || true
      kill "$pid" 2>/dev/null || true
    }

    # ── Displaying ───────────────────────────────────────────────────────
    show() {
      # Published first, on purpose. See the header.
      #
      # Truncate-in-place rather than write-a-temp-and-rename: the reader
      # watches this path with inotify, and a rename swaps the inode out from
      # under the watch. The file is one short line, and the reader ignores an
      # empty read for the microseconds where that matters.
      printf '%s\n' "$1" > "$STATE"

      ${pkgs.awww}/bin/awww img "$1" \
        --transition-type "$TRANSITION" \
        --transition-duration "$DURATION" \
        --transition-fps "$FPS" \
        --transition-bezier "${bezier}" \
        --resize crop \
        --filter Lanczos3
    }

    # awww-daemon is started by hyprland's own autostart, and racing it means
    # the first image is silently dropped. Poll rather than sleep a fixed
    # three seconds: usually this returns on the first try.
    for _ in $(${pkgs.coreutils}/bin/seq 1 40); do
      ${pkgs.awww}/bin/awww query >/dev/null 2>&1 && break
      sleep 0.5
    done

    # ── One image ────────────────────────────────────────────────────────
    if [ "$MODE" != "slideshow" ]; then
      if [ -n "$IMAGE" ] && [ -f "$IMAGE" ]; then
        show "$IMAGE"
      else
        echo "wallpaper-slideshow: no image set, or $IMAGE is missing" >&2
      fi
      # Idle rather than exit. Restart=always would otherwise turn a missing
      # file into a restart loop, and staying up keeps `systemctl restart` as
      # the panel's one apply path in both modes.
      while true; do nap 3600; done
    fi

    # ── Slideshow ────────────────────────────────────────────────────────
    WALLPAPERS=()

    scan() {
      WALLPAPERS=()
      [ -d "$DIR" ] || return
      while IFS= read -r -d "" file; do
        WALLPAPERS+=("$file")
      done < <(${pkgs.findutils}/bin/find -L "$DIR" -type f ${findExpr} -print0 | ${pkgs.coreutils}/bin/sort -z)
    }

    CURRENT=""

    # Sorted order when shuffle is off, and never the same image twice in a
    # row when it is on — a random pick that repeats reads as the slideshow
    # having stopped.
    pick() {
      local count=''${#WALLPAPERS[@]} choice i
      if [ "$count" -eq 1 ]; then
        printf '%s' "''${WALLPAPERS[0]}"
        return
      fi
      if [ "$SHUFFLE" = "true" ]; then
        choice="''${WALLPAPERS[$((RANDOM % count))]}"
        while [ "$choice" = "$CURRENT" ]; do
          choice="''${WALLPAPERS[$((RANDOM % count))]}"
        done
        printf '%s' "$choice"
        return
      fi
      for i in "''${!WALLPAPERS[@]}"; do
        if [ "''${WALLPAPERS[$i]}" = "$CURRENT" ]; then
          printf '%s' "''${WALLPAPERS[$(((i + 1) % count))]}"
          return
        fi
      done
      printf '%s' "''${WALLPAPERS[0]}"
    }

    while true; do
      # Re-scanned every tick rather than once at start, so dropping a file
      # into the directory does not need a restart to be picked up.
      scan

      if [ ''${#WALLPAPERS[@]} -eq 0 ]; then
        echo "wallpaper-slideshow: no images in $DIR" >&2
        nap 60
        continue
      fi

      NEXT=$(pick)
      show "$NEXT"
      CURRENT="$NEXT"

      SKIP=0
      nap "$INTERVAL"
      # SKIP is set by the trap and read here purely so the intent is legible;
      # either way the loop comes straight back round to the next image.
      : "$SKIP"
    done
  '';
in
{
  home.packages = [
    pkgs.awww
    wallpaper-slideshow
  ];

  systemd.user.services.wallpaper-slideshow = {
    Unit = {
      Description = "Wallpaper slideshow";
      After = "graphical-session.target";
      PartOf = "graphical-session.target";
    };
    Service = {
      ExecStart = "${wallpaper-slideshow}/bin/wallpaper-slideshow";
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
