{ ... }:
{
  wayland.windowManager.hyprland.settings = {
<<<<<<< HEAD
    input = {
      kb_layout = "ch";
      kb_variant = "de_nodeadkeys";
=======
    config.input = {
      kb_layout = "eu";
      kb_variant = "";
>>>>>>> 329bf83 (feat(hyprland) migration to lua)
      kb_model = "";
      kb_options = "";
      kb_rules = "";

      follow_mouse = 1;
      sensitivity = 0; # -1.0 - 1.0, 0 means no modification

      touchpad = {
        natural_scroll = false;
      };
    };

    # Per-device config — its own hl.device() call rather than a `device`
    # block inside the config table.
    device = [
      {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      }
    ];

    # Was `gesture = 3, horizontal, workspace` in default.nix's extraConfig.
    gesture = {
      fingers = 3;
      direction = "horizontal";
      action = "workspace";
    };
  };
}
