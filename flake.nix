{
  description = "My NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak?ref=latest";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    impermanence.url = "github:nix-community/impermanence";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hypr-bucket.url = "github:Time-0N/hypr-bucket";
    zen-browser.url = "github:youwen5/zen-browser-flake";
    gazelle.url = "github:Zeus-Deus/gazelle-tui";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixvim,
      ...
    }@inputs:
    {
      nixosConfigurations.DEG-PC-01 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          vars = import ./hosts/DEG-PC-01/variables.nix;
        };
        modules = [
          ./hosts/DEG-PC-01/configuration.nix
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.impermanence.nixosModules.impermanence
          inputs.nix-flatpak.nixosModules.nix-flatpak
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              vars = import ./hosts/DEG-PC-01/variables.nix;
            };
            home-manager.users.livio = import ./modules/home/default.nix;
            home-manager.sharedModules = [
              nixvim.homeModules.nixvim
            ];
          }
        ];
      };
    };
}
