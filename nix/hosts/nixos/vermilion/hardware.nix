_: {
  flake.nixosModules.vermilion = {
    hardware.cpu.amd.updateMicrocode = true;
    hardware.graphics.enable = true;
  };
}
