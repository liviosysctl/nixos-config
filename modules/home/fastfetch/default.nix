{ ... }:
{
  programs.fastfetch = {
    enable = true;

    settings = {
      logo = {
        type = "kitty-direct";
        source = "${../../../assets/fastfetch/pinguin.png}";
        width = 32;
        height = 18;
        padding = {
          top = 0;
          right = 2;
        };
      };

      display = {
        separator = ": ";
      };

      modules = [
        {
          type = "custom";
          key = "───────────── Hardware ─────────────";
          keyColor = "cyan";
          format = " ";
        }
        {
          type = "cpu";
          key = "󰻠 CPU";
          keyColor = "yellow";
        }
        {
          type = "gpu";
          key = "󰢮 GPU";
          keyColor = "yellow";
        }
        {
          type = "memory";
          key = "󰍛 RAM";
          keyColor = "yellow";
        }
        {
          type = "disk";
          key = "󰋊 Disk /";
          keyColor = "red";
          folders = "/";
        }
        {
          type = "disk";
          key = "󰋊 Disk /boot";
          keyColor = "red";
          folders = "/boot";
        }
        "break"
        {
          type = "custom";
          key = "───────────── Software ─────────────";
          keyColor = "cyan";
          format = " ";
        }
        {
          type = "os";
          key = "󱄅 OS";
          keyColor = "blue";
        }
        {
          type = "kernel";
          key = "󰌽 Kernel";
          keyColor = "blue";
        }
        {
          type = "packages";
          key = "󰏗 Packages";
          keyColor = "green";
        }
        {
          type = "wm";
          key = "󰍹 WM";
          keyColor = "green";
        }
        {
          type = "shell";
          key = "󰆍 Shell";
          keyColor = "green";
        }
        {
          type = "terminal";
          key = "󰞷 Terminal";
          keyColor = "green";
        }
        "break"
        {
          type = "custom";
          key = "─────────── Uptime / Age ───────────";
          keyColor = "cyan";
          format = " ";
        }
        {
          type = "command";
          key = "󰃭 OS Age";
          keyColor = "magenta";
          text = "birth_install=$(stat -c %W /); current=$(date +%s); echo $(( (current - birth_install) / 86400 )) days";
        }
        {
          type = "uptime";
          key = "󰅐 Uptime";
          keyColor = "magenta";
        }
      ];
    };
  };
}
