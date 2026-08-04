{ ... }:
{
  wayland.windowManager.hyprland.settings = {

    general = {
      border_size = 2;
    };

    # Window Rules (v2)
    windowrule = [
      # Float necessary windows
      "match:class ^(org.pulseaudio.pavucontrol)$, float on"
      "match:class ^$, match:title ^(Picture in picture)$, float on"
      "match:class ^$, match:title ^(Save File)$, float on"
      "match:class ^$, match:title ^(Open File)$, float on"
      "match:class ^(LibreWolf)$, match:title ^(Picture-in-Picture)$, float on"
      "match:class ^(blueman-manager)$, float on"
      "match:class ^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland)(.*)$, float on"
      "match:class ^(polkit-gnome-authentication-agent-1|hyprpolkitagent|org.org.kde.polkit-kde-authentication-agent-1)(.*)$, float on"
      "match:class ^(CachyOSHello)$, float on"
      "match:class ^(zenity)$, float on"
      "match:class ^$, match:title ^(Steam - Self Updater)$, float on"

      # Opacity
      "match:class ^(thunar|nemo)$, opacity 0.92"
      "match:class ^(discord|armcord|webcord)$, opacity 0.96"
      "match:class ^(dev.zed.Zed)$, opacity 0.85"
      "match:title ^(QQ|Telegram)$, opacity 0.95"
      "match:title ^(NetEase Cloud Music Gtk4)$, opacity 0.95"

      # Picture-in-Picture
      "match:title ^(Picture-in-Picture)$, float on"
      "match:title ^(Picture-in-Picture)$, size 960 540"
      "match:title ^(Picture-in-Picture)$, move ((monitor_w*0.75)-window_w) 0"

      # Floating media windows
      "match:title ^(danmufloat)$, pin on"
      "match:title ^(danmufloat|termfloat)$, rounding 5"

      # Animations
      "match:class ^(kitty|Alacritty)$, animation slide right"
      "match:class ^(org.mozilla.firefox)$, no_blur on"

      # Floating windows on workspaces 1-10
      "match:float true, match:workspace w[fv1-10], border_size 2"
      "match:float true, match:workspace w[fv1-10], rounding 8"

      # Tiling windows on workspaces 1-10
      "match:float false, match:workspace f[1-10], border_size 3"
      "match:float false, match:workspace f[1-10], rounding 4"

      # Ignore maximize requests
      "match:class .*, suppress_event maximize"

      # XWayland dragging fix
      "match:class ^$, match:title ^$, match:xwayland true, match:float true, match:fullscreen false, match:pin false, no_focus on"

      # Gazelle TUI pop-up
      "match:class ^(gazelle-network)$, float on"
      "match:class ^(gazelle-network)$, center on"
      "match:class ^(gazelle-network)$, size 800 800"

    ];

    # Workspace Rules
    workspace = [
      "w[tv1-10], gapsout:5, gapsin:3"
      "f[1], gapsout:5, gapsin:3"
    ];

    # Layer Rules
    layerrule = [
      "match:namespace ^(logout_dialog)$, animation slide top"
      "match:namespace ^(waybar)$, animation slide down"
      "match:namespace ^(wallpaper)$, animation fade 50%"

      # Hyprbucket
      "match:namespace ^(hyprbucket)$, blur on"
      "match:namespace ^(hyprbucket)$, ignore_alpha 0.5"

      # Waybar
      "match:namespace ^(waybar)$, blur on"
      "match:namespace ^(waybar)$, ignore_alpha 0.5"
    ];

    # XWayland scaling fix
    xwayland = {
      force_zero_scaling = true;
    };
  };
}
