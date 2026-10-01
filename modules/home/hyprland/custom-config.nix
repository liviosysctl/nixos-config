{ lib, pkgs, ... }:
let
  # Startpunkt für die Custom-Session. Bewusst winzig: alles Weitere schreibst
  # du selbst, ohne Rebuild.
  #
  # Nur APIs, die in der aktuellen Lua-Doku belegt sind — hl.config, hl.monitor,
  # hl.bind mit hl.dsp.exec_cmd. Dispatcher-Namen jenseits davon bitte am Wiki
  # gegenprüfen, die Lua-API ist noch jung.
  seed = pkgs.writeText "hyprland-custom.lua" ''
    -- Custom-Rice-Spielplatz. Diese Datei gehört DIR, nicht Nix.
    -- Nix legt sie einmalig an und rührt sie danach nie wieder an.
    -- Geladen wird sie über den Session-Eintrag "Hyprland Custom (UWSM)",
    -- definiert in modules/core/hyprland-custom-session.nix.
    --
    -- Reload im laufenden Betrieb: einfach speichern, oder `hyprctl reload`.

    hl.monitor({
      output = "",
      mode = "preferred",
      position = "auto",
      scale = "auto",
    })

    hl.config({
      general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        layout = "dwindle",
      },
      misc = {
        disable_hyprland_logo = true,
      },
    })

    -- Minimum, um wieder rauszukommen und ein Terminal zu haben.
    -- `uwsm stop` beendet die Session sauber inklusive aller User-Units;
    -- ein reines Beenden des Compositors würde die Units stehen lassen.
    hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("uwsm app -- kitty"))
    hl.bind("SUPER + M", hl.dsp.exec_cmd("uwsm stop"))
  '';
in
{
  # Gleiche Logik wie createMonitorsConf: einmal seeden, nie überschreiben.
  # Ein `home.file`/`xdg.configFile` wäre hier falsch — das würde die Datei bei
  # jedem Rebuild durch einen Store-Symlink ersetzen und deine Änderungen
  # wegwerfen.
  home.activation.seedHyprlandCustomConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    HYPR_DIR="$HOME/.config/hypr"
    mkdir -p "$HYPR_DIR"

    if [ ! -e "$HYPR_DIR/hyprland-custom.lua" ]; then
      cp ${seed} "$HYPR_DIR/hyprland-custom.lua"
      chmod u+w "$HYPR_DIR/hyprland-custom.lua"
    fi
  '';
}
