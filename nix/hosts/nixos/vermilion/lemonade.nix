_: {
  flake.nixosModules.vermilion = {config, ...}: {
    hardware.amd-npu = {
      enableROCm = true;
      gpuTarget = "gfx1151";
      lemonade = {
        host = "0.0.0.0";
        port = 13305;
        autoStart = true;
        flashAttn = "on";
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
          "builtin.Muse-Glimmer-30B-GGUF" = {
            ctx_size = 65536;
            llamacpp_args = "--spec-draft-n-max 3";
          };
          "builtin.Qwen3.6-35B-A3B-MTP-GGUF".ctx_size = 65536;
        };
        settings = {
          max_loaded_models = 1;
          auto_evict = false;
          global_timeout = 0;
          auto_update_models = false;
          auto_check_model_updates = true;
          telemetry.enabled = false;
          llamacpp.backend = "rocm";
        };
      };
      strata = {
        enable = true;
        quant = "UD-IQ4_XS";
        profile = "fast";
        contextSize = 262144;
        vision.enable = true;
        sampling = {
          temperature = 0.6;
          top_p = 0.95;
          top_k = 20;
        };
        extraArgs = [
          "--prompt-cache"
          "6"
          "--conversation-cache-mib"
          "16384"
          "--conversation-cache-slots"
          "16"
          "--conversation-cache-min-tokens"
          "2048"
          "--conversation-cache-min-free-mib"
          "2560"
          "--kv-resident"
          "32768"
        ];
        # Leave room for the other buffers within the default GTT limit.
        expertCache = 14000;
      };
    };

    systemd.services.lemond.environment.STRATA_PREFILL_STREAM_MIN = "128";

    networking.firewall.interfaces.cni0.allowedTCPPorts = [config.hardware.amd-npu.lemonade.port];
  };
}
