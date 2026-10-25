{
  inputs,
  self,
  ...
}: {
  config = {
    flake.nixosConfigurations.vermilion = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        inputs.determinate.nixosModules.default
        inputs.disko.nixosModules.disko
        inputs.sops-nix.nixosModules.sops
        self.nixosModules.aly
        self.nixosModules.autoUpgrade
        self.nixosModules.backups
        self.nixosModules.comin
        self.nixosModules.comfyui
        self.nixosModules.default
        self.nixosModules.k3s
        self.nixosModules.lanzaboote
        self.nixosModules.morgan
        self.nixosModules.ollama
        self.nixosModules.strata
        self.nixosModules.tailscale
        self.nixosModules.vermilion
        self.nixosModules.wifi
      ];

      specialArgs = {inherit self;};
    };

    blzrd.nodes.vermilion = {
      output = self.nixosConfigurations.vermilion.config.system.build.toplevel;
      type = "nixos";
      user = "root";
    };
  };
}
