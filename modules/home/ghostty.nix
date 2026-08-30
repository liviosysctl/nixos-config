{ ... }:
{
  programs.ghostty = {
    enable = true;

    settings = {
      # Gepatchte Nerd-Font-Variante: bringt die Prompt-Icons mit,
      # daher kein separater Symbols-Fallback nötig.
      font-family = "GeistMono Nerd Font Mono";
      font-style = "SemiBold";
      font-style-bold = "ExtraBold";
      font-size = 13;

      background = "1d2021";
      # Höher = mehr Terminal-Hintergrund, weniger Shader.
      background-opacity = 0.7;

      custom-shader = "${../../assets/shaders/balatro.glsl}";
      custom-shader-animation = true;

      cursor-style = "bar";
      scrollback-limit = 10000000;
      confirm-close-surface = false;

      window-padding-x = 8;
      window-padding-y = 8;
    };
  };
}
