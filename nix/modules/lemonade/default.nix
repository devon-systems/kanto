{inputs, ...}: {
  flake.nixosModules.lemonade = {
    imports = [inputs.nix-amd-ai.nixosModules.default];

    hardware.amd-npu = {
      enable = true;
      enableNPU = false;
      enableFastFlowLM = false;
      enableImageGen = false;
      lemonade = {
        user = "lemonade";
        cacheDir = "/var/lib/lemonade/models";
        desktopApp.enable = false;
      };
    };
  };
}
