{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    config.animations.enabled = true;

    # `bezier = "name, x1, y1, x2, y2"` became hl.curve(name, { ... }), which
    # also handles springs — hence the explicit type.
    curve = [
      {
        _args = [
          "wind"
          {
            type = "bezier";
            points = [
              [ 0.05 0.9 ]
              [ 0.1 1.0 ]
            ];
          }
        ];
      }
      {
        _args = [
          "winIn"
          {
            type = "bezier";
            points = [
              [ 0.1 1.0 ]
              [ 0.1 1.0 ]
            ];
          }
        ];
      }
      {
        _args = [
          "winOut"
          {
            type = "bezier";
            points = [
              [ 0.3 (-0.1) ]
              [ 0 1 ]
            ];
          }
        ];
      }
      {
        _args = [
          "liner"
          {
            type = "bezier";
            points = [
              [ 1 1 ]
              [ 1 1 ]
            ];
          }
        ];
      }
    ];

    # `animation = "NAME, ENABLED, SPEED, CURVE, STYLE"` became a named table.
    # The curve field is `bezier` even though hl.curve() defines it.
    animation = [
      {
        leaf = "windows";
        enabled = true;
        speed = 6;
        bezier = "wind";
        style = "slide";
      }
      {
        leaf = "windowsIn";
        enabled = true;
        speed = 6;
        bezier = "winIn";
        style = "slide";
      }
      {
        leaf = "windowsOut";
        enabled = true;
        speed = 5;
        bezier = "winOut";
        style = "slide";
      }
      {
        leaf = "windowsMove";
        enabled = true;
        speed = 5;
        bezier = "wind";
        style = "slide";
      }
      {
        leaf = "border";
        enabled = true;
        speed = 1;
        bezier = "liner";
      }
      {
        leaf = "borderangle";
        enabled = true;
        speed = 15;
        bezier = "liner";
        style = "loop";
      }
      {
        leaf = "fade";
        enabled = true;
        speed = 10;
        bezier = "default";
      }
      {
        leaf = "workspaces";
        enabled = true;
        speed = 5;
        bezier = "wind";
      }
      {
        leaf = "specialWorkspace";
        enabled = true;
        speed = 5;
        bezier = "wind";
        style = "slidevert";
      }
    ];
  };
}
