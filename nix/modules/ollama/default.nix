_: {
  flake.nixosModules.ollama = {config, ...}: {
    services.ollama = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = false;
      environmentVariables = {
        OLLAMA_NO_CLOUD = "1";
      };
    };

    # Only local pods can reach the unauthenticated inference API.
    networking.firewall.interfaces.cni0.allowedTCPPorts = [config.services.ollama.port];
  };
}
