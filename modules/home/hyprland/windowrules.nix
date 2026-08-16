{ lib, ... }:
let
  # Frosting, as a reusable pair of layer rules.
  #
  # There is only one blur on this desktop: `decoration:blur` in
  # decorations.nix, which the compositor applies to whatever is behind a
  # surface. A layer opts into it with `blur on`, and `ignore_alpha` says how
  # opaque a pixel has to be before it is worth blurring behind. 0.5 is the
  # threshold every translucent panel here runs, so they all frost
  # identically. Nothing may set its own: a panel that should look different
  # differs in what it paints, not in how the compositor blurs it.
  #
  # That number is load-bearing on the shell side too — qml/bar/theme/Theme.qml
  # keeps its island fill at or above it, and drops below it deliberately when
  # a pane is meant to go unfrosted. It is tested per pixel, not per surface.
  #
  # `popups` extends the same rules to xdg popups parented to the layer. The
  # quickshell cards are popup surfaces and would otherwise come out unfrosted
  # while the bar they hang off is not.
  frostedLayer =
    {
      namespace,
      popups ? false,
    }:
    [
      (
        {
          name = "${namespace}-blur";
          match.namespace = "^(${namespace})$";
          blur = true;
        }
        // lib.optionalAttrs popups { blur_popups = true; }
      )
      {
        name = "${namespace}-alpha";
        match.namespace = "^(${namespace})$";
        ignore_alpha = 0.5;
      }
    ];
in
{
  wayland.windowManager.hyprland.settings = {
    config = {
      general.border_size = 2;

      # XWayland scaling fix
      xwayland.force_zero_scaling = true;
    };

    # `windowrule = "match:class ^foo$, float on"` became a table with a
    # nested `match` set and the effects as sibling keys. Rules take a `name`
    # so they can be referenced and toggled later.
    window_rule = [
      # Float necessary windows
      {
        name = "float-pavucontrol";
        match = {
          class = "^(org.pulseaudio.pavucontrol)$";
        };
        float = true;
      }
      {
        name = "float-pip-blank";
        match = {
          class = "^$";
          title = "^(Picture in picture)$";
        };
        float = true;
      }
      {
        name = "float-save-file";
        match = {
          class = "^$";
          title = "^(Save File)$";
        };
        float = true;
      }
      {
        name = "float-open-file";
        match = {
          class = "^$";
          title = "^(Open File)$";
        };
        float = true;
      }
      {
        name = "float-librewolf-pip";
        match = {
          class = "^(LibreWolf)$";
          title = "^(Picture-in-Picture)$";
        };
        float = true;
      }
      {
        name = "float-blueman";
        match = {
          class = "^(blueman-manager)$";
        };
        float = true;
      }
      {
        name = "float-portals";
        match = {
          class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland)(.*)$";
        };
        float = true;
      }
      {
        name = "float-polkit";
        match = {
          class = "^(polkit-gnome-authentication-agent-1|hyprpolkitagent|org.org.kde.polkit-kde-authentication-agent-1)(.*)$";
        };
        float = true;
      }
      {
        name = "float-cachyos-hello";
        match = {
          class = "^(CachyOSHello)$";
        };
        float = true;
      }
      {
        name = "float-zenity";
        match = {
          class = "^(zenity)$";
        };
        float = true;
      }
      {
        name = "float-steam-updater";
        match = {
          class = "^$";
          title = "^(Steam - Self Updater)$";
        };
        float = true;
      }
      # Opacity
      {
        name = "opacity-filemanagers";
        match = {
          class = "^(thunar|nemo)$";
        };
        opacity = 0.92;
      }
      {
        name = "opacity-discord";
        match = {
          class = "^(discord|armcord|webcord)$";
        };
        opacity = 0.96;
      }
      {
        name = "opacity-chat";
        match = {
          title = "^(QQ|Telegram)$";
        };
        opacity = 0.95;
      }
      {
        name = "opacity-netease";
        match = {
          title = "^(NetEase Cloud Music Gtk4)$";
        };
        opacity = 0.95;
      }
      # Picture-in-Picture
      {
        name = "pip-float";
        match = {
          title = "^(Picture-in-Picture)$";
        };
        float = true;
      }
      {
        name = "pip-size";
        match = {
          title = "^(Picture-in-Picture)$";
        };
        size = "960 540";
      }
      {
        name = "pip-move";
        match = {
          title = "^(Picture-in-Picture)$";
        };
        move = "((monitor_w*0.75)-window_w) 0";
      }
      # Floating media windows
      {
        name = "danmufloat-pin";
        match = {
          title = "^(danmufloat)$";
        };
        pin = true;
      }
      {
        name = "mediafloat-rounding";
        match = {
          title = "^(danmufloat|termfloat)$";
        };
        rounding = 5;
      }
      # Animations
      {
        name = "terminal-slide";
        match = {
          class = "^(kitty|Alacritty)$";
        };
        animation = "slide right";
      }
      {
        name = "firefox-no-blur";
        match = {
          class = "^(org.mozilla.firefox)$";
        };
        no_blur = true;
      }
      # Floating windows on workspaces 1-10
      {
        name = "floating-ws-border";
        match = {
          float = true;
          workspace = "w[fv1-10]";
        };
        border_size = 2;
      }
      {
        name = "floating-ws-rounding";
        match = {
          float = true;
          workspace = "w[fv1-10]";
        };
        rounding = 8;
      }
      # Tiling windows on workspaces 1-10
      {
        name = "tiled-ws-border";
        match = {
          float = false;
          workspace = "f[1-10]";
        };
        border_size = 3;
      }
      {
        name = "tiled-ws-rounding";
        match = {
          float = false;
          workspace = "f[1-10]";
        };
        rounding = 4;
      }
      # Ignore maximize requests
      {
        name = "suppress-maximize";
        match = {
          class = ".*";
        };
        suppress_event = "maximize";
      }
      # XWayland dragging fix
      {
        name = "fix-xwayland-drags";
        match = {
          class = "^$";
          title = "^$";
          xwayland = true;
          float = true;
          fullscreen = false;
          pin = false;
        };
        no_focus = true;
      }
      # Gazelle TUI pop-up
      {
        name = "gazelle-float";
        match = {
          class = "^(gazelle-network)$";
        };
        float = true;
      }
      {
        name = "gazelle-center";
        match = {
          class = "^(gazelle-network)$";
        };
        center = true;
      }
      {
        name = "gazelle-size";
        match = {
          class = "^(gazelle-network)$";
        };
        size = "800 800";
      }
    ];

    workspace_rule = [
      {
        workspace = "w[tv1-10]";
        gaps_out = 5;
        gaps_in = 3;
      }
      {
        workspace = "f[1]";
        gaps_out = 5;
        gaps_in = 3;
      }
    ];

    layer_rule = [
      {
        name = "logout-dialog-anim";
        match = {
          namespace = "^(logout_dialog)$";
        };
        animation = "slide top";
      }
      {
        name = "wallpaper-anim";
        match = {
          namespace = "^(wallpaper)$";
        };
        animation = "fade 50%";
      }
      {
        name = "qs-bar-anim";
        match = {
          namespace = "^(qs-bar)$";
        };
        animation = "slide down";
      }
      # The settings overlay fades rather than slides — it covers the whole
      # output, and sliding a full-screen surface reads as the desktop moving.
      {
        name = "qs-settings-anim";
        match = {
          namespace = "^(qs-settings)$";
        };
        animation = "fade";
      }
    ]
    # Everything translucent gets the blur and nothing else. The quickshell
    # namespaces are set by hand in shell.qml and
    # settings/SettingsWindow.qml, because quickshell otherwise names every
    # surface it opens "quickshell" and these rules would catch any other
    # shell running alongside it.
    ++ frostedLayer { namespace = "hyprbucket"; }
    # wlogout names its layer `logout_dialog`. Its stylesheet puts a scrim on
    # `window` at 0.55 specifically so there is something above ignore_alpha
    # here for the compositor to blur behind — see modules/home/wlogout.nix.
    ++ frostedLayer { namespace = "logout_dialog"; }
    ++ frostedLayer {
      namespace = "qs-bar";
      popups = true;
    }
    ++ frostedLayer {
      namespace = "qs-settings";
      popups = true;
    };
  };
}
