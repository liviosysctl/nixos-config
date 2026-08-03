{ vars, config, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
  ];

  # ── Host-specific: Boot ────────────────────────────────────────
  # Windows-Eintrag kommt unter GRUB via os-prober (useOSProber in
  # modules/core/boot.nix) — kein manueller Eintrag mehr nötig.

  # ── Host-specific: Networking ──────────────────────────────────
  networking.hostName = vars.hostName;

  # ── Host-specific: GPU (Nvidia) ───────────────────────────────────
  services.xserver.videoDrivers = [ "nvidia" ];
  boot.kernelParams = [
    "nvidia_drm.modset=1"
    "nvidia_drm.fbdev=1"
  ];
  hardware.nvidia = {
    nvidiaSettings = true;
    open = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # ── Host-specific: Kernel module blacklist (IEM drivers) ───────
  boot.blacklistedKernelModules = [
    "mei"
    "mei_me"
  ];

  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  # ── Host-specific: Mount points ────────────────────────────────

}
