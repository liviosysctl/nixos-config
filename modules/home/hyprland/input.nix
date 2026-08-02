{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    input = {
      kb_layout = "ch";
      kb_variant = "de_nodeadkeys";
      kb_model = "";
      kb_options = "";
      kb_rules = "";

      follow_mouse = 1;
      sensitivity = 0; # -1.0 - 1.0, 0 means no modification

      touchpad = {
        natural_scroll = false;
      };
    };

    # Per-device config
    # See https://wiki.hypr.land/Configuring/Keywords/#per-device-input-configs
    device = [
      {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      }
    ];
  };
}
