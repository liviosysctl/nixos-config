{ pkgs, config, ... }:
let
  mountPoint = "${config.home.homeDirectory}/ProtonDrive";
  rcloneConf = "${config.home.homeDirectory}/.config/rclone/rclone.conf";
in
{
  # rclone selbst kommt bereits aus modules/home/packages.nix.
  # fuse3 wird für den fusermount3-Unmount-Befehl benötigt.
  home.packages = [ pkgs.fuse3 ];

  systemd.user.services.rclone-protondrive = {
    Unit = {
      Description = "Rclone-Mount für Proton Drive";
      After = [
        "graphical-session.target"
        "network-online.target"
      ];
      Wants = [ "network-online.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mountPoint}";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount proton: ${mountPoint} \
          --config ${rcloneConf} \
          --vfs-cache-mode full \
          --vfs-cache-max-age 24h \
          --vfs-cache-max-size 5G \
          --dir-cache-time 1m \
          --poll-interval 30s \
          --log-level INFO
      '';
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u ${mountPoint}";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
