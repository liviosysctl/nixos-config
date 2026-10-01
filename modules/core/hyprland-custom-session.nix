{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  configPath = "/home/${vars.username}/.config/hypr/hyprland-custom.lua";

  uwsm = lib.getExe config.programs.uwsm.package;

  # start-hyprland nimmt eigene Argumente nur nach einem `--` entgegen.
  # Das in die Desktop-Exec-Zeile zu schreiben hiesse zwei `--` hintereinander,
  # einmal für uwsm und einmal für start-hyprland — dieser Wrapper macht daraus
  # einen einzigen Aufruf ohne Trennzeichen-Raterei.
  #
  # /run/current-system/sw/bin/ statt eines Store-Pfads, damit die Session
  # immer gegen das Hyprland der aktiven Generation läuft.
  startCustom = pkgs.writeShellScriptBin "start-hyprland-custom" ''
    exec /run/current-system/sw/bin/start-hyprland -- --config ${configPath} "$@"
  '';

  # Handgebauter Session-Eintrag statt programs.uwsm.waylandCompositors:
  # dessen Generator hängt extraArgs hinter binPath, also an Hyprland, und
  # lässt keinen Platz für uwsm-eigene Flags wie -D.
  #
  # -D Hyprland und DesktopNames=Hyprland sind aus dem Eintrag des
  # Hyprland-Pakets übernommen. Ohne sie müsste uwsm die Desktop-Namen aus dem
  # Binary ableiten, und das Binary heisst hier start-hyprland-custom — davon
  # hinge XDG_CURRENT_DESKTOP und damit die Portal-Auswahl ab.
  #
  # providedSessions ist Pflicht: services.displayManager prüft das an jedem
  # Eintrag in sessionPackages. Der Wert muss dem Dateinamen ohne .desktop
  # entsprechen.
  session = pkgs.writeTextFile {
    name = "hyprland-custom-session";
    destination = "/share/wayland-sessions/hyprland-custom.desktop";
    text = ''
      [Desktop Entry]
      Name=Hyprland Custom
      Comment=Hyprland mit handgepflegter Config (nicht von Home Manager verwaltet)
      Exec=${uwsm} start -D Hyprland -- ${lib.getExe startCustom}
      TryExec=${uwsm}
      DesktopNames=Hyprland
      Type=Application
    '';
    derivationArgs.passthru.providedSessions = [ "hyprland-custom" ];
  };
in
{
  services.displayManager.sessionPackages = [ session ];
}
