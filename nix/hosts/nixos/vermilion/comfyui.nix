_: {
  flake.nixosModules.vermilion = {
    config,
    lib,
    pkgs,
    ...
  }: let
    rocmRuntime = pkgs.rocmPackages.rocm-runtime.overrideAttrs (old: {
      patches = old.patches ++ [./comfyui/rocr-polling-backoff.patch];
    });
    python = pkgs.python3.override {
      packageOverrides = final: prev: {
        torch = prev.torch.override {
          cudaSupport = false;
          rocmSupport = true;
          triton = final.triton-no-cuda;
        };
      };
    };
  in {
    services.comfyui = {
      enable = true;
      listen = ["0.0.0.0"];
      package = pkgs.comfyui.override {python3 = python;};
      models = [
        {
          name = "z_image_turbo_bf16.safetensors";
          url = "https://huggingface.co/Comfy-Org/Z-Image-Turbo/resolve/6fc90a3b1b653e935a0d175e260736de25b84df5/split_files/diffusion_models/z_image_turbo_bf16.safetensors";
          hash = "sha256-JAdhMFC4Cf/f8YpKyZr4Pqa5VEPs69+A4GSnnIJVdKY=";
          installPaths = "diffusion_models";
        }
        {
          name = "qwen_3_4b.safetensors";
          url = "https://huggingface.co/Comfy-Org/Z-Image-Turbo/resolve/6fc90a3b1b653e935a0d175e260736de25b84df5/split_files/text_encoders/qwen_3_4b.safetensors";
          hash = "sha256-bGcUmFc6wvelUBUCzM6NKwjqbKL2YcRY5wjzazbt/Fo=";
          installPaths = "text_encoders";
        }
        {
          name = "ae.safetensors";
          url = "https://huggingface.co/Comfy-Org/Z-Image-Turbo/resolve/6fc90a3b1b653e935a0d175e260736de25b84df5/split_files/vae/ae.safetensors";
          hash = "sha256-r8jignLNFds5GbrNtpGM6cHtIulssSxNXtD7qCNSnjg=";
          installPaths = "vae";
        }
        {
          name = "krea2_turbo_bf16.safetensors";
          url = "https://huggingface.co/Comfy-Org/Krea-2/resolve/1171f4dc7e325bf3734586942e737872506c73e1/diffusion_models/krea2_turbo_bf16.safetensors";
          hash = "sha256-eLv49BZe2hnOo8sGx4CJIhkyo54u7Yr52nQflCxH/7M=";
          installPaths = "diffusion_models";
        }
        {
          name = "qwen3vl_4b_bf16.safetensors";
          url = "https://huggingface.co/Comfy-Org/Krea-2/resolve/1171f4dc7e325bf3734586942e737872506c73e1/text_encoders/qwen3vl_4b_bf16.safetensors";
          hash = "sha256-NvP/RH71kgFyLo+c5gIMmBn9z7pqomCMTgmxwM4RTjQ=";
          installPaths = "text_encoders";
        }
        {
          name = "qwen_image_vae.safetensors";
          url = "https://huggingface.co/Comfy-Org/Krea-2/resolve/1171f4dc7e325bf3734586942e737872506c73e1/vae/qwen_image_vae.safetensors";
          hash = "sha256-pwWA8CE+Z5Z+6clfBbtADo+wgwfgF6kkvzRBIj4CPR8=";
          installPaths = "vae";
        }
      ];
    };

    users.users.comfyui.extraGroups = ["render" "video"];

    # Load Torch's OpenMP runtime first to avoid an initialization deadlock.
    systemd.services.comfyui.environment.LD_PRELOAD = "${pkgs.stdenv.cc.cc.lib}/lib/libgomp.so.1 ${rocmRuntime}/lib/libhsa-runtime64.so.1";

    systemd.services.comfyui.preStart = lib.mkAfter ''
      install -Dm644 ${./comfyui/workflows/z-image-turbo.json} ${config.services.comfyui.dataDir}/user/default/workflows/z-image-turbo.json
      install -Dm644 ${./comfyui/workflows/krea2-turbo.json} ${config.services.comfyui.dataDir}/user/default/workflows/krea2-turbo.json
    '';

    # HTTPS reaches this service through the in-cluster proxy.
    networking.firewall.interfaces.cni0.allowedTCPPorts = [config.services.comfyui.port];
  };
}
