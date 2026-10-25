_: {
  flake.nixosModules.k3s = {
    config,
    self,
    ...
  }: {
    sops.secrets.k3s-token = {
      sopsFile = self + "/secrets/k3s.yaml";
      key = "TOKEN";
      mode = "0400";
    };

    services.k3s = {
      enable = true;
      tokenFile = config.sops.secrets.k3s-token.path;
      gracefulNodeShutdown = {
        enable = true;
        shutdownGracePeriod = "45s";
        shutdownGracePeriodCriticalPods = "10s";
      };
    };

    networking.firewall = {
      checkReversePath = "loose";
      interfaces.cni0.allowedTCPPorts = [10250];
    };
  };
}
