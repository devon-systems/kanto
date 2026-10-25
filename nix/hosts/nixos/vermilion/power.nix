_: {
  flake.nixosModules.vermilion = {
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="platform-profile", ATTR{name}=="amd-pmf", ATTR{profile}="performance"
    '';
  };
}
