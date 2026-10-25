_: {
  flake.nixosModules.vermilion = {
    nix.settings = {
      max-jobs = 2;
      cores = 4;
    };
  };
}
