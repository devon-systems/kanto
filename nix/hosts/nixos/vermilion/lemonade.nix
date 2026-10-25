_: {
  flake.nixosModules.vermilion = {
    hardware.amd-npu = {
      gpuTarget = "gfx1151";
      lemonade.settings.max_loaded_models = 1;
      strata = {
        enable = true;
        quant = "UD-IQ4_XS";
        profile = "defaults";
      };
    };
  };
}
