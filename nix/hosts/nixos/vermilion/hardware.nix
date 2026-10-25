_: {
  flake.nixosModules.vermilion = {pkgs, ...}: {
    environment.systemPackages = [pkgs.nvtopPackages.amd];

    hardware.cpu.amd.updateMicrocode = true;
    hardware.graphics.enable = true;
  };
}
