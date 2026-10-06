{ ... }:
{

  # `env = "KEY,value"` became a two-argument hl.env("KEY", "value") call,
  # which is what the _args list produces.
  wayland.windowManager.hyprland.settings.env = [
    # Cursor
    { _args = [ "XCURSOR_THEME" "Bibata-Modern-Classic" ]; }
    { _args = [ "XCURSOR_SIZE" "24" ]; }
    { _args = [ "HYPRCURSOR_SIZE" "24" ]; }
    { _args = [ "QT_CURSOR_SIZE" "24" ]; }

    { _args = [ "LIBVA_DRIVER_NAME" "nvidia" ]; }
    { _args = [ "__GLX_VENDOR_LIBRARY_NAME" "nvidia" ]; }
    { _args = [ "NVD_BACKEND" "direct" ]; }

    # Session
    { _args = [ "XDG_SESSION_TYPE" "wayland" ]; }
    { _args = [ "XDG_CURRENT_DESKTOP" "Hyprland" ]; }
    { _args = [ "XDG_SESSION_DESKTOP" "Hyprland" ]; }

    # Qt theming
    { _args = [ "QT_QPA_PLATFORMTHEME" "qt6ct" ]; }
    { _args = [ "QT_STYLE_OVERRIDE" "kvantum" ]; }
  ];
}
