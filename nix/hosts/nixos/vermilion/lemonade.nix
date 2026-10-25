_: {
  flake.nixosModules.vermilion = {config, ...}: {
    hardware.amd-npu = {
      enableROCm = true;
      gpuTarget = "gfx1151";
      lemonade = {
        host = "0.0.0.0";
        allowedOrigins = ["https://openwebui.narwhal-snapper.ts.net"];
        settings = {
          max_loaded_models = 1;
          llamacpp.backend = "rocm";
        };
      };
      strata = {
        enable = true;
        quant = "UD-IQ4_XS";
        profile = "fast";
        extraArgs = ["--conversation-cache-mib" "8192"];
        # Leave room for the other buffers within the default GTT limit.
        expertCache = 14000;
      };
    };

    networking.firewall.interfaces.cni0.allowedTCPPorts = [config.hardware.amd-npu.lemonade.port];
  };
}
