_: {
  flake.nixosModules.vermilion = {
    hardware.amd-npu = {
      gpuTarget = "gfx1151";
      lemonade.settings.max_loaded_models = 1;
      strata = {
        enable = true;
        quant = "UD-IQ4_XS";
        profile = "fast";
        extraArgs = ["--conversation-cache-mib" "8192"];
        # Leave room for the other buffers within the default GTT limit.
        expertCache = 14000;
      };
    };
  };
}
