{
  pkgs,
  lib,
  ...
}:
let
  # Ore-UI-Theme-Pack, gepinnt auf Release 1.0.
  # Enthält sechs Widget-Themes und ein Icon-Pack.
  oreUI = pkgs.fetchFromGitHub {
    owner = "ninsent";
    repo = "Ore-UI-theme-pack";
    rev = "1.0";
    hash = "sha256-wkbqrPrDZjVZ0S/3125YPajqoyGccISZ6l5tVk0+Rvs=";
  };

  # Verzeichnisnamen aus dem Repo. Sie werden 1:1 zu den Theme-Ordnernamen
  # unter ~/.local/share/PrismLauncher/themes und sind damit auch die IDs,
  # die Prism in prismlauncher.cfg unter ApplicationTheme ablegt.
  themeNames = [
    "Ore UI - Dark Amethyst"
    "Ore UI - Dark Diamond"
    "Ore UI - Dark Emerald"
    "Ore UI - Light Amethyst"
    "Ore UI - Light Diamond"
    "Ore UI - Light Emerald"
  ];
in
{
  programs.prismlauncher = {
    enable = true;

    # Jedes Theme wird als vollständiges Verzeichnis verlinkt. Das HM-Modul
    # setzt dabei recursive = true, legt also einen echten, beschreibbaren
    # Ordner an und symlinkt nur die einzelnen Dateien in den Store.
    themes = lib.genAttrs themeNames (name: "${oreUI}/${name}");
  };

  # Icon-Themes kennt das prismlauncher-Modul (noch) nicht, deshalb von Hand.
  # Prism erwartet .../PrismLauncher/iconthemes/<name>/index.theme.
  xdg.dataFile."PrismLauncher/iconthemes/Ore UI" = {
    source = "${oreUI}/Ore UI - Icon Pack";
    recursive = true;
  };
}
