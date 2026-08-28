{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*".addKeysToAgent = "yes";

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/github-sshkey";
        identitiesOnly = true;
      };
    };
  };

  services.ssh-agent.enable = true;
}
