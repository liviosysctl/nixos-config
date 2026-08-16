{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    env = [

      # NVIDIA
      "LIBVA_DRIVER_NAME,nvidia"
      "__GLX_VENDOR_LIBRARY_NAME,nvidia"
      "NVD_BACKEND,direct"

      # Cursor
      "XCURSOR_THEME,WiiPointer"
      "XCURSOR_SIZE,24"
      "HYPRCURSOR_SIZE,24"
      "QT_CURSOR_SIZE,24"

      # Session
      "XDG_SESSION_TYPE,wayland"
      "XDG_CURRENT_DESKTOP,Hyprland"
      "XDG_SESSION_DESKTOP,Hyprland"

      # Qt theming
      "QT_QPA_PLATFORMTHEME,qt6ct"
      "QT_STYLE_OVERRIDE,kvantum"
    ];
  };
}
