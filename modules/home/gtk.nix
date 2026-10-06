{ pkgs, config, ... }:
let
  gtk-theme-name = "Colloid-Dark";
  gtk-theme = pkgs.colloid-gtk-theme;
  icon-theme-name = "Papirus-Dark";
  cursor-name = "Bibata-Modern-Classic";
  cursor-theme = pkgs.bibata-cursors;
  cursor-size = 24;
in
{
  fonts.fontconfig.enable = true;

  gtk = {
    enable = true;

    font = {
      name = "CodeNewRoman Nerd Font Propo";
      size = 12;
      package = pkgs.nerd-fonts.code-new-roman;
    };

    theme = {
      name = gtk-theme-name;
      package = gtk-theme;
    };

    iconTheme = {
      name = icon-theme-name;
      package = pkgs.papirus-icon-theme;
    };

    cursorTheme = {
      name = cursor-name;
      package = cursor-theme;
      size = cursor-size;
    };

    gtk3 = {
      bookmarks = [
        "file://${config.home.homeDirectory}/downloads"
        "file://${config.home.homeDirectory}/pictures"
        "file://${config.home.homeDirectory}/videos"
        "file://${config.home.homeDirectory}/documents"
      ];

      extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
    };

    gtk4 = {
      theme = {
        name = gtk-theme-name;
        package = gtk-theme;
      };
      extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      gtk-theme = gtk-theme-name;
      icon-theme = icon-theme-name;
      color-scheme = "prefer-dark";
      cursor-theme = cursor-name;
      cursor-size = cursor-size;
    };
  };

  home.pointerCursor = {
    name = cursor-name;
    package = cursor-theme;
    size = cursor-size;
    gtk.enable = true;
    x11.enable = true;
  };
}
