_: {
  flake.nixosModules.vermilion = {
    config,
    lib,
    pkgs,
    ...
  }: {
    assertions = [
      {
        assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.18.4";
        message = "Strix Halo requires the KFD fixes in Linux 6.18.4 or newer.";
      }
    ];

    boot.kernelPackages = pkgs.linuxPackages_latest;
  };
}
