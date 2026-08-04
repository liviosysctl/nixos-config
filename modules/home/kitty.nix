{ pkgs, ... }:
{
  home.packages = with pkgs; [
    geist-font
  ];
  programs.kitty = {
    enable = true;
    font = {
      name = "Geist Mono";
      size = 13.0;
    };
    settings = {
      bold_font = "Geist Mono Bold";
      italic_font = "Geist Mono Italic";
      bold_italic_font = "Geist Mono Bold Italic";

      background_opacity = "0.85";
      cursor_shape = "beam";
      cursor_trail = 1;
      enable_audio_bell = "no";
      hide_window_decorations = "yes";
      confirm_os_window_close = 0;
      background = "#1d2021";
      background_blur = 20;
      dynamic_background_opacity = "yes";
      window_padding_width = 5;

      scrollback_lines = 5000;

      repaint_delay = 10;
      input_delay = 1;
      sync_to_monitor = "yes";

      # Nerd-Font-Icons per Fallback statt gepatchtem Hauptfont, siehe
      # https://sw.kovidgoyal.net/kitty/faq/#kitty-is-not-able-to-use-my-favorite-font
      symbol_map = "U+23FB-U+23FE,U+2665,U+26A1,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0D4,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6AA,U+E700-U+E7C5,U+EA60-U+EBEB,U+F000-U+F2E0,U+F300-U+F532,U+F0001-U+F1AF0 Symbols Nerd Font Mono";
    };
  };
}
