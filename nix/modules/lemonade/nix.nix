_: {
  flake.nixosModules.lemonade.nix.settings = {
    substituters = ["https://nix-amd-ai.cachix.org"];
    trusted-public-keys = ["nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="];
  };
}
