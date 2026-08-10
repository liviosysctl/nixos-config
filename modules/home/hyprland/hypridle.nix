{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wl-gammarelay-rs
  ];

  services.hypridle = {
    enable = true;
    systemdTarget = "graphical-session.target";

    settings = {
      general = {
        before_sleep_cmd = "sh -c 'pidof hyprlock || hyprlock'";
        after_sleep_cmd = "hyprctl dispatch dpms on && busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Brightness d 1.0";
        # 0 would take no sleep inhibitor at all, so before_sleep_cmd is not
        # guaranteed to have painted before the machine goes down -- a lid close
        # from an unlocked desktop can resume to a briefly visible session.
        # 2 (auto, the upstream default) holds a *delay* inhibitor and releases it
        # once the session actually reports locked, via hyprland_lock_notification_v1.
        # Not 3: hypridle then consumes the lock notification itself and
        # on_lock_cmd / on_unlock_cmd stop working.
        inhibit_sleep = 2;
      };

      listener = [
        {
          timeout = 120;
          on-timeout = "busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Brightness d 0.5";
          on-resume = "busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Brightness d 1.0";
        }
        {
          timeout = 300;
          on-timeout = "hyprlock";
        }
        {
          timeout = 360;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
          # Deliberately NOT ignore_inhibit: playing media should hold suspend off,
          # so a film you are actually watching does not get cut short.
          # The cost, accepted knowingly: hypridle drops a timeout that lands while
          # an inhibitor is held rather than deferring it, and nothing retries until
          # the next idle period. So a stray inhibit at the 30 min mark -- Zen raises
          # one whenever media is loaded -- silently skips that suspend.
        }
      ];
    };
  };

  systemd.user.services.wl-gammarelay-rs = {
    Unit = {
      Description = "wl-gammarelay-rs";
      After = "graphical-session.target";
      PartOf = "graphical-session.target";
    };
    Service = {
      ExecStart = "${pkgs.wl-gammarelay-rs}/bin/wl-gammarelay-rs run";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
