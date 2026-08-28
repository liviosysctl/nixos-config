{ pkgs, ... }:
let
  # modrinth-app stirbt unter Hyprland sofort nach dem Start mit
  #   Gdk-Message: Error 71 (Protocol error) dispatching to Wayland display.
  # Workaround: GTK auf XWayland zwingen und die beiden WebKit-Renderpfade
  # abschalten, die unter Wayland/Nvidia bekannt problematisch sind.
  #
  # Bewusst als eigener symlinkJoin mit wrapProgram statt als overrideAttrs auf
  # gappsWrapperArgs: modrinth-app ist selbst ein symlinkJoin und ruft wrapGApp
  # manuell im postBuild auf (nixpkgs PR #542808, Juli 2026). Ein Override auf
  # diese interne Hook-Mechanik bricht bei jeder Umstellung wieder weg.
  modrinth-app-x11 = pkgs.symlinkJoin {
    name = "modrinth-app-x11";
    paths = [ pkgs.modrinth-app ];

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      wrapProgram "$out/bin/ModrinthApp" \
        --set GDK_BACKEND x11 \
        --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
        --set WEBKIT_DISABLE_COMPOSITING_MODE 1

      # Der Desktop-Entry zeigt sonst weiter auf das ungewrappte Binary, womit
      # der Start aus dem Anwendungsmenue den Wrapper umgehen wuerde.
      shopt -s nullglob
      for f in "$out"/share/applications/*.desktop; do
        target=$(readlink -f "$f")
        rm "$f"
        sed -E "s|^Exec=[^ ]*ModrinthApp|Exec=$out/bin/ModrinthApp|" "$target" > "$f"
      done
    '';

    meta = pkgs.modrinth-app.meta // {
      mainProgram = "ModrinthApp";
    };
  };
in
{
  home.packages = [ modrinth-app-x11 ];
}
