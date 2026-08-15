{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    # Build tools
    gcc
    gnumake
    unzip
    nodejs

    # Desktop apps
    vesktop
    vlc
    evince
    swayimg
    pinta
    gimp3-with-plugins
    obsidian
    qbittorrent
    proton-vpn
    protonmail-desktop
    jellyfin-desktop
    fuzzel # Clipboard selector
    kid3
    feishin
    modrinth-app

    # 3D
    #temp removed due to upstream test failure: freecad
    blender

    # Android dev
    android-tools

    # File managers
    yazi

    # Cli tools
    lsd
    ffmpeg
    flac

    # Monitoring
    btop

    # Wayland / Hyprland utilities
    grim
    slurp
    satty
    wl-clipboard
    playerctl
    nwg-displays
    wlr-randr
    # wlogout is installed by programs.wlogout in ./wlogout.nix, which owns its
    # layout and stylesheet too. Listing it here as well would work but would
    # hide where it is actually configured.
    pavucontrol
    cava
    blueman
    ffmpegthumbnailer
    screen

    # Theming
    papirus-icon-theme

    # Wine and Proton
    wineWow64Packages.staging
    winetricks
    protonup-qt

    # Language runtimes
    rustc
    cargo
    python3
    ghc

    # Clanker tooling
    claude-code

    # Flake packages
    inputs.hypr-bucket.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
