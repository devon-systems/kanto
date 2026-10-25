_: {
  flake.nixosModules.vermilion = {pkgs, ...}: let
    python = pkgs.python3.override {
      packageOverrides = final: prev: {
        torch = prev.torch.override {
          cudaSupport = false;
          rocmSupport = true;
          triton = final.triton-no-cuda;
        };
      };
    };
  in {
    services.comfyui.package = pkgs.comfyui.override {python3 = python;};
  };
}
