{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.code-new-roman
      nerd-fonts.geist-mono
      nerd-fonts.symbols-only
      open-sans
      overpass
    ];
    fontconfig.enable = true;
  };
}
