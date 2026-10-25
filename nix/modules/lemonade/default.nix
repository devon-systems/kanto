{inputs, ...}: {
  flake.nixosModules.lemonade = {config, ...}: {
    imports = [inputs.nix-amd-ai.nixosModules.default];

    hardware.amd-npu = {
      enable = true;
      enableNPU = false;
      enableFastFlowLM = false;
      enableImageGen = false;
      lemonade = {
        user = "lemonade";
        host = "0.0.0.0";
        cacheDir = "/var/lib/lemonade/models";
        desktopApp.enable = false;
        allowedOrigins = ["https://openwebui.narwhal-snapper.ts.net"];
      };
    };

    users.groups.lemonade = {};
    users.users.lemonade = {
      isSystemUser = true;
      group = "lemonade";
      extraGroups = ["render" "video"];
      home = "/var/lib/lemonade";
      createHome = true;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/lemonade/models/hf 0750 lemonade lemonade -"
      "d /var/lib/lemonade/models/lemonade 0750 lemonade lemonade -"
    ];

    networking.firewall.interfaces.cni0.allowedTCPPorts = [config.hardware.amd-npu.lemonade.port];

    nix.settings = {
      substituters = ["https://nix-amd-ai.cachix.org"];
      trusted-public-keys = ["nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="];
    };
  };
}
