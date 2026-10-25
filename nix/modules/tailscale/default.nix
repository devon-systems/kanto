_: {
  flake.nixosModules.tailscale = {
    config,
    self,
    ...
  }: {
    sops.secrets.tailscale-auth-key.sopsFile = self + "/secrets/tailscale.yaml";
    services.tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscale-auth-key.path;
      openFirewall = true;
      # Keep the host's port policy under NixOS firewall control.
      extraUpFlags = ["--ssh" "--accept-routes=false" "--netfilter-mode=off"];
    };

    networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [22];
  };
}
