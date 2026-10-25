_: {
  flake.nixosModules.vermilion = {
    config,
    pkgs,
    ...
  }: let
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
    };

    users.users.comfyui.extraGroups = ["render" "video"];

    # HTTPS reaches this service through the in-cluster proxy.
    networking.firewall.interfaces.cni0.allowedTCPPorts = [config.services.comfyui.port];
  };
}
