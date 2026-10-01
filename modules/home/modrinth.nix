{ lib, pkgs, ... }:
let
  # Eskalationsleiter für WebKitGTK auf Nvidia. Reihenfolge und Bewertung aus
  # der Tauri-Doku "Linux Graphics Issues" — je weiter unten, desto mehr
  # Hardwarebeschleunigung fällt weg. Nur so weit gehen wie nötig.
  #
  #   Stufe 1  nvidia_drm.modeset=1
  #            steht bereits in hosts/DEG-PC-01/configuration.nix
  #   Stufe 2  __NV_DISABLE_EXPLICIT_SYNC=1
  #            aktiv; behebt Wayland-"Error 71", kostet keine Performance
  #   Stufe 3  WEBKIT_DISABLE_DMABUF_RENDERER=1
  #            kostet den schnellen Renderpfad
  #   Stufe 4  WEBKIT_DISABLE_COMPOSITING_MODE=1
  #            schaltet beschleunigtes Compositing komplett ab
  #
  # Alles wird mit --set-default gesetzt: eine Variable, die schon in der
  # Shell steht, gewinnt. Höhere Stufen lassen sich also ohne Rebuild testen:
  #   WEBKIT_DISABLE_DMABUF_RENDERER=1 ModrinthApp
  # und erst wenn eine Stufe wirklich nötig ist, hier fest eintragen.
  nvidiaEnv = {
    __NV_DISABLE_EXPLICIT_SYNC = "1";
    # WEBKIT_DISABLE_DMABUF_RENDERER = "1";
    # WEBKIT_DISABLE_COMPOSITING_MODE = "1";
  };

  wrapperArgs = lib.concatStringsSep " " (
    lib.mapAttrsToList (n: v: "--set-default ${n} ${lib.escapeShellArg v}") nvidiaEnv
  );

  modrinth-app = pkgs.symlinkJoin {
    pname = "modrinth-app-nvidia";
    inherit (pkgs.modrinth-app) version;

    paths = [ pkgs.modrinth-app ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      wrapProgram "$out/bin/ModrinthApp" ${wrapperArgs}

      # Die .desktop-Datei ist im Join nur ein Symlink in den Store-Pfad des
      # Originalpakets. Ohne Umschreiben startet der Menüeintrag am Wrapper
      # vorbei und die Variablen oben greifen nur beim Start aus der Shell.
      shopt -s nullglob
      entries=("$out"/share/applications/*.desktop)
      if [ ''${#entries[@]} -eq 0 ]; then
        echo "modrinth.nix: keine .desktop-Datei im Paket gefunden" >&2
        exit 1
      fi
      for entry in "''${entries[@]}"; do
        original="$(readlink -f "$entry")"
        rm "$entry"
        install -m644 "$original" "$entry"
        sed -i -E "s|^Exec=[^ ]+|Exec=$out/bin/ModrinthApp|" "$entry"
      done
    '';

    meta = pkgs.modrinth-app.meta // {
      mainProgram = "ModrinthApp";
    };
  };
in
{
  home.packages = [ modrinth-app ];
}
