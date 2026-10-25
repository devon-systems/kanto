_: {
  flake.nixosModules.vermilion = {config, ...}: {
    hardware.amd-npu = {
      enableROCm = true;
      gpuTarget = "gfx1151";
      lemonade = {
        host = "0.0.0.0";
        allowedOrigins = ["https://openwebui.narwhal-snapper.ts.net"];
        models = [
          "Muse-Glimmer-30B-GGUF"
          "Qwen3.6-35B-A3B-MTP-GGUF"
          "user.Qwen3.8-27B-DFlash-GGUF"
        ];
        customModels."Qwen3.8-27B-DFlash-GGUF" = {
          checkpoints = {
            main = "unsloth/Qwen3.8-27B-GGUF:Qwen3.8-27B-UD-Q4_K_XL.gguf";
            mmproj = "unsloth/Qwen3.8-27B-GGUF:mmproj-F16.gguf";
            draft = "ggml-org/Qwen3.8-27B-GGUF:dflash-Qwen3.8-27B-Q8_0.gguf";
          };
          recipe = "llamacpp";
          labels = ["chat" "reasoning" "vision" "tool-calling" "dflash"];
          recipe_options = {
            ctx_size = 65536;
            llamacpp_args = "--spec-draft-n-max 3";
          };
        };
        recipeOptions = {
          "builtin.Muse-Glimmer-30B-GGUF".ctx_size = 65536;
          "builtin.Qwen3.6-35B-A3B-MTP-GGUF".ctx_size = 65536;
        };
        settings = {
          max_loaded_models = 1;
          llamacpp.backend = "rocm";
        };
      };
      strata = {
        enable = true;
        quant = "UD-IQ4_XS";
        profile = "fast";
        contextSize = 262144;
        extraArgs = [
          "--conversation-cache-mib"
          "8192"
          "--kv-resident"
          "32768"
        ];
        # Leave room for the other buffers within the default GTT limit.
        expertCache = 14000;
      };
    };

    networking.firewall.interfaces.cni0.allowedTCPPorts = [config.hardware.amd-npu.lemonade.port];
  };
}
