{ ... }:
{
  wayland.windowManager.hyprland.settings.config = {
    decoration = {
      rounding = 10;
      rounding_power = 3;

      active_opacity = 1.0;
      inactive_opacity = 1.0;

      shadow = {
        enabled = true;
        range = 10;
        render_power = 2;
        color = "rgba(00000050)";
        color_inactive = "rgba(00000000)";
      };

      blur = {
        enabled = true;
        size = 3;
        passes = 3;
        new_optimizations = true;
        ignore_opacity = true;
        xray = false;
      };
    };

    cursor = {
      inactive_timeout = 2;
    };
  };
}
