_: {
  flake.nixosModules.vermilion = {pkgs, ...}: {
    environment.systemPackages = [pkgs.nvtopPackages.amd];

    hardware.amd-npu.gpuMemory.ttmSizeGiB = 96;
    hardware.cpu.amd.updateMicrocode = true;
    hardware.graphics.enable = true;
  };
}
