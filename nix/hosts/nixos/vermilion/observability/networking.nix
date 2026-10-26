_: {
  flake.nixosModules.vermilion = {config, ...}: {
    networking.firewall.interfaces = {
      cni0.allowedTCPPorts = [3020 3030];
      "flannel.1".allowedTCPPorts = [3020 3030];
      ${config.services.tailscale.interfaceName}.allowedTCPPorts = [3020 3030];
    };
  };
}
