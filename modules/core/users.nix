{ pkgs, vars, ... }:
{
  users.users.livio = {
    isNormalUser = true;
    description = vars.username;
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "video"
      "storage"
      "adbusers"
      "kvm"
    ];
    shell = pkgs.zsh;
  };
}
