{ lib, ... }:
let
  inherit (import ./variables.nix)
    terminal
    fileManager
    menu
    ;

  inherit (lib.generators) mkLuaInline;
in
{
  wayland.windowManager.hyprland.settings = {
    config.binds = {
      movefocus_cycles_fullscreen = true;
    };

    # Every bind is hl.bind(key, dispatcher, opts?). The old bind/bindm/bindel/
    # bindl variants collapse into the third options table.
    bind = [
      # Reload the bar
      {
        _args = [
          "SUPER + SHIFT + B"
          (mkLuaInline "hl.dsp.exec_cmd([[systemctl --user restart qs-bar]])")
        ];
      }

      # Keybinds
      {
        _args = [
          "SUPER + RETURN"
          (mkLuaInline "hl.dsp.exec_cmd([[${terminal}]])")
        ];
      }

      {
        _args = [
          "SUPER + Q"
          (mkLuaInline "hl.dsp.window.close()")
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + M"
          (mkLuaInline "hl.dsp.exec_cmd([[session-menu]])")
        ];
      }

      {
        _args = [
          "SUPER + E"
          (mkLuaInline "hl.dsp.exec_cmd([[${fileManager}]])")
        ];
      }

      {
        _args = [
          "SUPER + V"
          (mkLuaInline ''hl.dsp.window.float({ action = "toggle" })'')
        ];
      }

      {
        _args = [
          "SUPER + SPACE"
          (mkLuaInline "hl.dsp.exec_cmd([[${menu}]])")
        ];
      }

      {
        _args = [
          "SUPER + F"
          (mkLuaInline "hl.dsp.window.fullscreen({ mode = 'fullscreen', action = 'toggle' })")
        ];
      }

      {
        _args = [
          "SUPER + P"
          (mkLuaInline "hl.dsp.window.pseudo()")
        ];
      }

      {
        _args = [
          "SUPER + J"
          (mkLuaInline ''hl.dsp.layout("togglesplit")'')
        ];
      }

      {
        _args = [
          "SUPER + L"
          (mkLuaInline "hl.dsp.exec_cmd([[lockscreen]])")
        ];
      }

      {
        _args = [
          "SUPER + Tab"
          (mkLuaInline "hl.dsp.group.next()")
        ];
      }

      # Screenshot
      {
        _args = [
          "SUPER + SHIFT + S"
          (mkLuaInline ''hl.dsp.exec_cmd([[grim -g "$(slurp -o -r -c '##00000000')" -t ppm - | satty --filename - --fullscreen --copy-command 'wl-copy' --output-filename ~/pictures/screenshots/satty-$(date '+%Y%m%d-%H:%M:%S').png]])'')
        ];
      }

      # Clipboard history (requires cliphist)
      {
        _args = [
          "SUPER + CTRL + V"
          (mkLuaInline "hl.dsp.exec_cmd([[cliphist list | fuzzel --dmenu | cliphist decode | wl-copy]])")
        ];
      }

      # Move focus with mainMod + arrow keys
      {
        _args = [
          "SUPER + left"
          (mkLuaInline ''hl.dsp.focus({ direction = "left" })'')
        ];
      }

      {
        _args = [
          "SUPER + right"
          (mkLuaInline ''hl.dsp.focus({ direction = "right" })'')
        ];
      }

      {
        _args = [
          "SUPER + up"
          (mkLuaInline ''hl.dsp.focus({ direction = "up" })'')
        ];
      }

      {
        _args = [
          "SUPER + down"
          (mkLuaInline ''hl.dsp.focus({ direction = "down" })'')
        ];
      }

      # Switch workspaces with mainMod + [0-9]
      {
        _args = [
          "SUPER + 1"
          (mkLuaInline "hl.dsp.focus({ workspace = 1 })")
        ];
      }

      {
        _args = [
          "SUPER + 2"
          (mkLuaInline "hl.dsp.focus({ workspace = 2 })")
        ];
      }

      {
        _args = [
          "SUPER + 3"
          (mkLuaInline "hl.dsp.focus({ workspace = 3 })")
        ];
      }

      {
        _args = [
          "SUPER + 4"
          (mkLuaInline "hl.dsp.focus({ workspace = 4 })")
        ];
      }

      {
        _args = [
          "SUPER + 5"
          (mkLuaInline "hl.dsp.focus({ workspace = 5 })")
        ];
      }

      {
        _args = [
          "SUPER + 6"
          (mkLuaInline "hl.dsp.focus({ workspace = 6 })")
        ];
      }

      {
        _args = [
          "SUPER + 7"
          (mkLuaInline "hl.dsp.focus({ workspace = 7 })")
        ];
      }

      {
        _args = [
          "SUPER + 8"
          (mkLuaInline "hl.dsp.focus({ workspace = 8 })")
        ];
      }

      {
        _args = [
          "SUPER + 9"
          (mkLuaInline "hl.dsp.focus({ workspace = 9 })")
        ];
      }

      {
        _args = [
          "SUPER + 0"
          (mkLuaInline "hl.dsp.focus({ workspace = 10 })")
        ];
      }

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      {
        _args = [
          "SUPER + SHIFT + 1"
          (mkLuaInline "hl.dsp.window.move({ workspace = 1 })")
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + 2"
          (mkLuaInline "hl.dsp.window.move({ workspace = 2 })")
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + 3"
          (mkLuaInline "hl.dsp.window.move({ workspace = 3 })")
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + 4"
          (mkLuaInline "hl.dsp.window.move({ workspace = 4 })")
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + 5"
          (mkLuaInline "hl.dsp.window.move({ workspace = 5 })")
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + 6"
          (mkLuaInline "hl.dsp.window.move({ workspace = 6 })")
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + 7"
          (mkLuaInline "hl.dsp.window.move({ workspace = 7 })")
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + 8"
          (mkLuaInline "hl.dsp.window.move({ workspace = 8 })")
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + 9"
          (mkLuaInline "hl.dsp.window.move({ workspace = 9 })")
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + 0"
          (mkLuaInline "hl.dsp.window.move({ workspace = 10 })")
        ];
      }

      # Scroll through existing workspaces with mainMod + scroll
      {
        _args = [
          "SUPER + mouse_down"
          (mkLuaInline ''hl.dsp.focus({ workspace = "e+1" })'')
        ];
      }

      {
        _args = [
          "SUPER + mouse_up"
          (mkLuaInline ''hl.dsp.focus({ workspace = "e-1" })'')
        ];
      }

      # Move window towards a direction
      {
        _args = [
          "SUPER + SHIFT + left"
          (mkLuaInline ''hl.dsp.window.move({ direction = "left" })'')
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + right"
          (mkLuaInline ''hl.dsp.window.move({ direction = "right" })'')
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + up"
          (mkLuaInline ''hl.dsp.window.move({ direction = "up" })'')
        ];
      }

      {
        _args = [
          "SUPER + SHIFT + down"
          (mkLuaInline ''hl.dsp.window.move({ direction = "down" })'')
        ];
      }

      # bindm: drag/resize with mainMod + LMB/RMB
      {
        _args = [
          "SUPER + mouse:272"
          (mkLuaInline "hl.dsp.window.drag()")
          { mouse = true; }
        ];
      }

      {
        _args = [
          "SUPER + mouse:273"
          (mkLuaInline "hl.dsp.window.resize()")
          { mouse = true; }
        ];
      }

      # bindel: works while locked, repeats on hold
      {
        _args = [
          "XF86AudioRaiseVolume"
          (mkLuaInline "hl.dsp.exec_cmd([[wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+]])")
          {
            locked = true;
            repeating = true;
          }
        ];
      }

      {
        _args = [
          "XF86AudioLowerVolume"
          (mkLuaInline "hl.dsp.exec_cmd([[wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-]])")
          {
            locked = true;
            repeating = true;
          }
        ];
      }

      {
        _args = [
          "XF86AudioMute"
          (mkLuaInline "hl.dsp.exec_cmd([[wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle]])")
          {
            locked = true;
            repeating = true;
          }
        ];
      }

      {
        _args = [
          "XF86AudioMicMute"
          (mkLuaInline "hl.dsp.exec_cmd([[wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle]])")
          {
            locked = true;
            repeating = true;
          }
        ];
      }

      {
        _args = [
          "XF86MonBrightnessUp"
          (mkLuaInline "hl.dsp.exec_cmd([[brightnessctl -e4 -n2 set 5%+]])")
          {
            locked = true;
            repeating = true;
          }
        ];
      }

      {
        _args = [
          "XF86MonBrightnessDown"
          (mkLuaInline "hl.dsp.exec_cmd([[brightnessctl -e4 -n2 set 5%-]])")
          {
            locked = true;
            repeating = true;
          }
        ];
      }

      # bindl: works while locked (requires playerctl)
      {
        _args = [
          "XF86AudioNext"
          (mkLuaInline "hl.dsp.exec_cmd([[playerctl next]])")
          { locked = true; }
        ];
      }

      {
        _args = [
          "XF86AudioPause"
          (mkLuaInline "hl.dsp.exec_cmd([[playerctl play-pause]])")
          { locked = true; }
        ];
      }

      {
        _args = [
          "XF86AudioPlay"
          (mkLuaInline "hl.dsp.exec_cmd([[playerctl play-pause]])")
          { locked = true; }
        ];
      }

      {
        _args = [
          "XF86AudioPrev"
          (mkLuaInline "hl.dsp.exec_cmd([[playerctl previous]])")
          { locked = true; }
        ];
      }
    ];
  };
}
