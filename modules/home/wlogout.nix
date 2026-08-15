{ pkgs, ... }:
# The session menu behind the bar's nix logo (qml/bar/session/PowerWidget.qml)
# and SUPER+X in keybinds.nix.
#
# Adapted from a HyDE wlogout theme, which is a *template* rather than a
# config: the original is full of `${fntSize}`, `${BtnCol}`, `${mgn}` and so
# on, substituted by a shell script at runtime. Three things in it do not
# survive the move, and all three are fixed below rather than carried over
# broken:
#
#   1. `${...}` is nix interpolation here, not shell. Those become the `let`
#      bindings below, so they are set once at build time and are actually
#      greppable.
#   2. It imported `~/.config/waybar/theme.css` for `@main-bg`, `@wb-act-bg`
#      and `@wb-hvr-bg`. That file went with the waybar module, so the colours
#      are defined here instead, taken from the same palette the bar falls back
#      to in qml/bar/theme/Palette.qml.
#   3. Its icons were `$HOME/.config/wlogout/icons/lock_${BtnCol}.png` with
#      `/usr/share/...` fallbacks — neither of which exists on this machine.
#      See `icons` below.
let
  # ── Metrics ────────────────────────────────────────────────────────────
  fontSize = 16;
  # Resting margin around each button, and the smaller one it shrinks to on
  # hover. `hoverMargin` must stay under `margin` — that difference *is* the
  # grow-on-hover effect, and inverting it makes buttons shrink instead.
  margin = 15;
  hoverMargin = 10;
  # The outer corners of the strip, and the radius a button takes while lit.
  buttonRadius = 20;
  activeRadius = 20;

  # ── Palette ────────────────────────────────────────────────────────────
  # From qml/bar/theme/Palette.qml's fixed values: @background #1d2021,
  # @color6 #bfd7ea, @color4 #ffc8d8. Deliberately not wallpaper-derived —
  # wlogout is a separate process with no access to the shell's palette, and a
  # session menu that changed colour with the desktop would be the one place
  # you would rather it did not.
  buttonColour = "#bfd7ea";
  # The scrim behind everything. **Above 0.5 on purpose**: that is Hyprland's
  # `ignore_alpha` for this layer, and anything under it is left sharp. This is
  # what actually produces the blur — the layer rule in
  # hyprland/windowrules.nix only opts the surface in, it cannot blur behind
  # something transparent. The original theme had `window` fully transparent,
  # which is why the desktop showed through untouched.
  windowBg = "rgba(0, 0, 0, 0.55)";
  # Light glass, not dark fill. The original's near-opaque dark buttons made
  # sense over a clear backdrop; over a dimmed one they disappear into it. Same
  # arrangement the bar uses — dark scrim, panes lighter than it.
  mainBg = "rgba(191, 215, 234, 0.08)";
  focusBg = "rgba(191, 215, 234, 0.20)";
  hoverBg = "rgba(255, 200, 216, 0.26)";

  # ── Icons ──────────────────────────────────────────────────────────────
  # wlogout ships its own set, but they are **pure black with an alpha
  # channel** — on a dark panel they are invisible, which is exactly why the
  # HyDE theme referenced `_white` variants it generated itself. So they get
  # recoloured here at build time to match the button text.
  #
  # `-colorize 100` moves every pixel fully to the fill colour and leaves the
  # alpha channel alone, which is what preserves the icon's shape.
  icons = pkgs.runCommand "wlogout-icons-tinted" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    mkdir -p "$out"
    for icon in ${pkgs.wlogout}/share/wlogout/icons/*.png; do
      magick "$icon" -fill "${buttonColour}" -colorize 100 "$out/$(basename "$icon")"
    done
  '';
  # wlogout lays its buttons out in a grid and defaults to **3 per row**, so
  # six buttons come out 3x2. This theme is drawn as a single horizontal strip
  # — only the outer two corners are rounded and the margins are left/right —
  # so at the default it renders as a scattered grid with rounding on the wrong
  # edges and icons at double the intended size. `-b 6` is not a preference,
  # it is what the stylesheet assumes.
  #
  # Wrapped rather than passed at each call site, for the same reason
  # `lockscreen` is wrapped in hyprland/lockscreen.nix: two callers already
  # exist (the bar's nix glyph and SUPER+X), and a flag the stylesheet depends
  # on should not be something a third caller can forget.
  sessionMenu = pkgs.writeShellScriptBin "session-menu" ''
    exec ${pkgs.wlogout}/bin/wlogout --buttons-per-row 6 "$@"
  '';
in
{
  home.packages = [ sessionMenu ];

  programs.wlogout = {
    enable = true;

    layout = [
      {
        label = "lock";
        # `lockscreen`, not the theme's `lockscreen.sh`. It is the single
        # entry point defined in hyprland/lockscreen.nix and already used by
        # keybinds.nix and hypridle.nix.
        action = "lockscreen";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        # The original said `hyde-shell logout`, which is HyDE's own tool.
        # This session is run by uwsm — wayland-wm@hyprland.desktop.service is
        # what reaches graphical-session.target — so stopping it is what
        # actually ends the session cleanly, taking every user unit with it.
        # `hyprctl dispatch exit` would kill the compositor and leave the
        # units behind.
        action = "uwsm stop";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        # The theme ran `lockscreen & disown && systemctl suspend`. Not needed
        # here: hypridle already holds a delay inhibitor and runs
        # `before_sleep_cmd = "lockscreen"`, so suspending locks on the way
        # down and does it in the right order. Racing a second lock against
        # that is what the pgrep guard in lockscreen.nix exists to survive,
        # not something to go looking for.
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate";
        keybind = "h";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
    ];

    style = ''
      /* Adapted from a HyDE wlogout theme. See modules/home/wlogout.nix for
         what changed and why — in particular, there is no @import here: the
         waybar theme.css this used to pull its colours from is gone. */

      @define-color main-bg ${mainBg};
      @define-color act-bg ${focusBg};
      @define-color hvr-bg ${hoverBg};

      * {
        background-image: none;
        font-size: ${toString fontSize}px;
      }

      window {
        background-color: ${windowBg};
      }

      button {
        color: ${buttonColour};
        background-color: @main-bg;
        outline-style: none;
        border: none;
        border-width: 0px;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 20%;
        border-radius: 0px;
        box-shadow: none;
        text-shadow: none;
      }

      button:focus {
        background-color: @act-bg;
        background-size: 30%;
      }

      button:hover {
        background-color: @hvr-bg;
        background-size: 40%;
        border-radius: ${toString activeRadius}px;
        transition: all 0.3s cubic-bezier(0.55, 0.0, 0.28, 1.682);
      }

      /* Hover pulls the margins in, which is what makes the button appear to
         grow. Only the outermost pair keep their outer margin, so the strip
         does not detach from the screen edge. */
      button:hover#lock {
        border-radius: ${toString activeRadius}px;
        margin: ${toString hoverMargin}px 0px ${toString hoverMargin}px ${toString margin}px;
      }

      button:hover#logout,
      button:hover#suspend,
      button:hover#hibernate,
      button:hover#shutdown {
        border-radius: ${toString activeRadius}px;
        margin: ${toString hoverMargin}px 0px ${toString hoverMargin}px 0px;
      }

      button:hover#reboot {
        border-radius: ${toString activeRadius}px;
        margin: ${toString hoverMargin}px ${toString margin}px ${toString hoverMargin}px 0px;
      }

      /* Only the two ends are rounded, so the six buttons read as one strip.
         Order here must match the layout above. */
      #lock {
        background-image: url("${icons}/lock.png");
        border-radius: ${toString buttonRadius}px 0px 0px ${toString buttonRadius}px;
        margin: ${toString margin}px 0px ${toString margin}px ${toString margin}px;
      }

      #logout {
        background-image: url("${icons}/logout.png");
        margin: ${toString margin}px 0px ${toString margin}px 0px;
      }

      #suspend {
        background-image: url("${icons}/suspend.png");
        margin: ${toString margin}px 0px ${toString margin}px 0px;
      }

      #hibernate {
        background-image: url("${icons}/hibernate.png");
        margin: ${toString margin}px 0px ${toString margin}px 0px;
      }

      #shutdown {
        background-image: url("${icons}/shutdown.png");
        margin: ${toString margin}px 0px ${toString margin}px 0px;
      }

      #reboot {
        background-image: url("${icons}/reboot.png");
        border-radius: 0px ${toString buttonRadius}px ${toString buttonRadius}px 0px;
        margin: ${toString margin}px ${toString margin}px ${toString margin}px 0px;
      }
    '';
  };
}
