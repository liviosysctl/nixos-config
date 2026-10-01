{
  username = "livio";
  hostName = "DEG-PC-01";

  gitUsername = "<NEUER-USERNAME>";
  gitEmail = "<NEUE-EMAIL>";
  gitGpgKey = ""; # Only activates when set! On new devices key needs to be re-generated. Generate -> "gpg --full-generate-key" Get ID -> "gpg --list-secret-keys --keyid-format=long" Export -> "gpg --armor --export <key-id>"

  timeZone = "Europe/Zurich";

  browser = "zen";
  terminal = "kitty";

  tailscale = false;

  secureBoot = false;

  mimeDefaultApps = {
    # File Manager
    "inode/directory" = [ "org.gnome.Nautilus.desktop" ];

    # Text Editor
    "text/plain" = [ "neovim-kitty.desktop" ];
    "text/markdown" = [ "neovim-kitty.desktop" ];
    "text/x-python" = [ "neovim-kitty.desktop" ];
    "text/x-shellscript" = [ "neovim-kitty.desktop" ];
    "text/x-c" = [ "neovim-kitty.desktop" ];
    "text/x-rust" = [ "neovim-kitty.desktop" ];
    "application/json" = [ "neovim-kitty.desktop" ];
    "text/xml" = [ "neovim-kitty.desktop" ];

    # Web
    "text/html" = [ "zen.desktop" ];
    "x-scheme-handler/http" = [ "zen.desktop" ];
    "x-scheme-handler/https" = [ "zen.desktop" ];
    "x-scheme-handler/about" = [ "zen.desktop" ];
    "x-scheme-handler/unknown" = [ "zen.desktop" ];

    # Images
    "image/jpeg" = [ "swayimg.desktop" ];
    "image/png" = [ "swayimg.desktop" ];
    "image/gif" = [ "swayimg.desktop" ];
    "image/webp" = [ "swayimg.desktop" ];
    "image/svg+xml" = [ "swayimg.desktop" ];

    # Audio & Video
    "video/mp4" = [ "vlc.desktop" ];
    "video/x-matroska" = [ "vlc.desktop" ];
    "video/webm" = [ "vlc.desktop" ];
    "video/x-msvideo" = [ "vlc.desktop" ];
    "audio/mpeg" = [ "vlc.desktop" ];
    "audio/flac" = [ "vlc.desktop" ];
    "audio/ogg" = [ "vlc.desktop" ];
    "audio/x-wav" = [ "vlc.desktop" ];

    # Documents
    "application/pdf" = [ "org.gnome.Evince.desktop" ];
    "application/postscript" = [ "org.gnome.Evince.desktop" ];

    # Torrents
    "application/x-bittorrent" = [ "org.qbittorrent.qBittorrent.desktop" ];
    "x-scheme-handler/magnet" = [ "org.qbittorrent.qBittorrent.desktop" ];
  };
}
