_: {
  flake.nixosModules.default = {pkgs, ...}: {
    environment.systemPackages = [pkgs.ripgrep];
  };
}
