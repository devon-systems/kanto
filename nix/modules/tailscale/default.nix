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
      extraUpFlags = ["--accept-routes=false" "--netfilter-mode=off"];
    };

    # Use OpenSSH keys for shared-node logins, and keep Ollama off the tailnet.
    networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [22];
  };
}
