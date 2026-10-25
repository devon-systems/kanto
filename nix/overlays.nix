{inputs, ...}: {
  flake.overlays.default = inputs.nix-amd-ai.overlays.default;
}
