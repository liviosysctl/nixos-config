{ vars, ... }:
{
  imports = [
    ./cliphist.nix
    ./direnv.nix
    ./nautilus.nix
    ./xdg.nix
    ./desktop-entries.nix
    ./cli/git.nix
    ./cli/lazygit.nix
    ./fastfetch
    ./packages.nix
    ./ssh.nix
    ./zsh.nix
    ./gtk.nix
    ./qt.nix
    ./qml.nix
    ./wlogout.nix
    ./gazelle.nix
    ./hyprland
    ./starship.nix
    ./kitty.nix
    ./zen-browser.nix
    ./nixvim
    ./spicetify.nix
    ./supersonic.nix
    ./modrinth.nix
    ./zed.nix
  ];
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";
  home.sessionVariables = {
    BROWSER = vars.browser;
    TERMINAL = vars.terminal;
  };
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;
}
