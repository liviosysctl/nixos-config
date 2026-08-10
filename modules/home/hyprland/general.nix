{ ... }:
{
  wayland.windowManager.hyprland.settings.config = {
    general = {
      gaps_in = 15;
      gaps_out = 25;

      border_size = 2;

      # Gradients are a table now rather than a "colA colB 45deg" string, and
      # the dotted "col.active_border" key becomes a nested `col` table.
      col = {
        active_border = {
          colors = [
            "rgba(8080c0ee)"
            "rgba(2f3c48ee)"
          ];
          angle = 45;
        };
        inactive_border = "rgba(00000000)";
      };

      resize_on_border = true;
      extend_border_grab_area = 20;
      hover_icon_on_border = false;
      allow_tearing = false;

      layout = "dwindle";
    };

    dwindle = {
      preserve_split = true;
    };

    master = {
      new_status = "master";
    };

    misc = {
      disable_hyprland_logo = true;
    };
  };
}
