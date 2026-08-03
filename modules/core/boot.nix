{
  pkgs,
  lib,
  vars,
  config,
  ...
}:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    # ── Bootloader ───────────────────────────────────────────────
    # GRUB ist aktiv, solange secureBoot = false.
    # Bei secureBoot = true übernimmt lanzaboote (systemd-boot-basiert);
    # GRUB und lanzaboote schliessen sich gegenseitig aus.
    loader = {
      grub = {
        enable = !vars.secureBoot;
        device = "nodev"; # EFI: GRUB wird in die ESP installiert
        efiSupport = true;
        useOSProber = true; # findet den Windows Boot Manager
        configurationLimit = 20;

        minegrub-world-sel = {
          enable = true;
          customIcons = with config.system; [
            {
              inherit name;
              lineTop = with nixos; "${distroName} ${codeName} (${version})";
              lineBottom = "Survival Mode, No Cheats, Version: ${nixos.release}";
              imgName = "nixos";
            }
          ];
        };
      };

      efi.canTouchEfiVariables = true;
      timeout = 10;
    };

    lanzaboote = lib.mkIf vars.secureBoot or false {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    # ── Kernel params (quiet boot) ───────────────────────────────
    kernelParams = [
      "consoleblank=60"
      "quiet"
      "logo.nologo"
      "systemd.show_status=auto"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=auto"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];

    consoleLogLevel = 3;
    initrd.verbose = false;
  };

  environment.systemPackages = with pkgs; [ sbctl ];
}
