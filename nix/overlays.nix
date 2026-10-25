{inputs, ...}: {
  flake.overlays = {
    default = _final: prev: {
      inherit (inputs.nix-amd-ai.packages.${prev.stdenv.hostPlatform.system}) strata;
    };
  };
}
