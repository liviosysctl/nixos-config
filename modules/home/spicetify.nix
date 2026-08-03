{ pkgs, inputs, ... }:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;

    theme = {
      name = "Hazy";
      src = pkgs.fetchFromGitHub {
        owner = "Astromations";
        repo = "Hazy";
        rev = "1926d9db3e0313b68ca6e2193c2b278e733ac3c4";
        hash = "sha256-2D8hcPaAqsXv7krzd8n77LqxaQzf2GMCqiDuq1YHLks=";
      };
      # Flags gemäss Hazy-Installationsanleitung
      injectCss = true;
      injectThemeJs = true;
      replaceColors = true;
      overwriteAssets = true;
    };
    colorScheme = "Base"; # Hazy hat nur dieses eine Schema

    # Marketplace: nur zum Stöbern (Installieren geht mit spicetify-nix nicht)
    enabledCustomApps = with spicePkgs.apps; [
      marketplace
    ];

    enabledExtensions = with spicePkgs.extensions; [
      adblock
      hidePodcasts
      shuffle
    ];
  };
}
