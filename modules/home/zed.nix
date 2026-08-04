{
  pkgs,
  lib,
  config,
  ...
}:
{
  programs.zed-editor = {
    enable = true;

    extensions = [
      "nix"
      "toml"
      "lua"
      "dockerfile"
      "docker-compose"
    ];
    # Bash/Shell-Script-Unterstützung ist seit Zed 1.3.0 nativ eingebaut;
    # die separate "bash"-Extension ist deprecated und daher bewusst nicht gelistet.

    # Läuft in Zeds eigenem FHS-Environment. Wichtig auf NixOS: von Extensions
    # selbst heruntergeladene LSP-Binaries (z. B. nixd) scheitern oft am fehlenden
    # dynamischen Linker. Mit extraPackages nutzt Zed stattdessen die Store-Version.
    extraPackages = with pkgs; [
      nixd
      nixfmt
      shfmt
      shellcheck
    ];

    userSettings = {
      auto_update = false;

      theme = {
        mode = "dark";
        dark = "One Dark";
        light = "One Light";
      };

      # Experimentell — laut offenem Zed-Issue #38995 tut dieses Setting auf
      # mehreren Plattformen aktuell schlicht nichts. Schadet aber nicht, falls
      # es doch greift. Verlässlicher Weg ist die Hyprland-Windowrule weiter
      # unten in modules/home/hyprland/windowrules.nix.
      "experimental.theme_overrides" = {
        "background.appearance" = "blurred";
      };

      buffer_font_family = "Geist Mono";
      buffer_font_size = 14;
      ui_font_size = 15;

      git = {
        git_gutter = "tracked_files";
        inline_blame = {
          enabled = true;
        };
      };

      terminal = {
        dock = "bottom";
      };

      languages = {
        Nix = {
          language_servers = [
            "nixd"
            "!nil"
          ];
          formatter = {
            external = {
              command = "nixfmt";
              arguments = [ ];
            };
          };
          format_on_save = "on";
        };
        "Shell Script" = {
          formatter = {
            external = {
              command = "shfmt";
              arguments = [
                "-i"
                "2"
              ];
            };
          };
          format_on_save = "on";
        };
      };
    };
  };

  # Überschreibt den von zed-editor mitgelieferten Launcher-Eintrag (gleiche
  # Desktop-Datei-ID "dev.zed.Zed"), damit Zed beim Start immer $HOME öffnet.
  # ~/.local/share/applications hat laut XDG-Spec Vorrang vor dem paketeigenen
  # Eintrag. %U bleibt erhalten, damit "Öffnen mit Zed" für einzelne Dateien
  # weiterhin funktioniert (öffnet dann Home + die Datei).
  xdg.desktopEntries."dev.zed.Zed" = {
    name = "Zed";
    genericName = "Text Editor";
    comment = "A high-performance, multiplayer code editor";
    exec = "${lib.getExe pkgs.zed-editor} ${config.home.homeDirectory} %U";
    icon = "zed";
    type = "Application";
    terminal = false;
    categories = [
      "Utility"
      "TextEditor"
      "Development"
    ];
  };
}
