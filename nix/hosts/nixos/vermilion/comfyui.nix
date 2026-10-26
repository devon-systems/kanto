_: {
  flake.nixosModules.vermilion = {
    config,
    lib,
    pkgs,
    ...
  }: let
    modelManifest = pkgs.writeText "comfyui-models.json" (builtins.toJSON (import ./comfyui/_models.nix));
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
      # Fused attention corrupts longer Qwen text encodings on gfx1151.
      extraArgs = ["--use-split-cross-attention"];
    };

    users.users.comfyui.extraGroups = ["render" "video"];

    systemd.services.comfyui-models = {
      description = "Download ComfyUI models";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "comfyui.service"];
      path = [pkgs.coreutils pkgs.curl pkgs.jq];
      script = "${pkgs.bash}/bin/bash ${./comfyui/fetch-models.sh} ${modelManifest} ${lib.escapeShellArg "${config.services.comfyui.dataDir}/models"}";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "comfyui";
        Group = "comfyui";
        StateDirectory = "comfyui";
        StateDirectoryMode = "0700";
        TimeoutStartSec = "infinity";
      };
    };

    systemd.services.comfyui = {
      preStart = lib.mkAfter ''
        install -Dm644 ${./comfyui/workflows/z-image-turbo.json} ${config.services.comfyui.dataDir}/user/default/workflows/z-image-turbo.json
        install -Dm644 ${./comfyui/workflows/krea2-turbo.json} ${config.services.comfyui.dataDir}/user/default/workflows/krea2-turbo.json
      '';
    };

    # HTTPS reaches this service through the in-cluster proxy.
    networking.firewall.interfaces.cni0.allowedTCPPorts = [config.services.comfyui.port];
  };
}
