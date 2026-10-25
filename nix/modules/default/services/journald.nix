_: {
  flake.nixosModules.default = {
    services.journald.settings.Journal.SystemMaxUse = "1G";
  };
}
