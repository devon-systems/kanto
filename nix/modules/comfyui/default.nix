_: {
  flake.nixosModules.comfyui = {config, ...}: {
    services.comfyui = {
      enable = true;
      listen = ["0.0.0.0"];
    };

    users.users.comfyui.extraGroups = ["render" "video"];

    # HTTPS reaches this service through the in-cluster proxy.
    networking.firewall.interfaces.cni0.allowedTCPPorts = [config.services.comfyui.port];
  };
}
