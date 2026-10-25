_: {
  flake.nixosModules.vermilion = {self, ...}: {
    hardware.facter.reportPath = self + "/nix/hosts/nixos/vermilion/facter.json";
  };
}
