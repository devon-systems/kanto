_: {
  flake.nixosModules.vermilion = {
    systemd.tmpfiles.rules = [
      "w /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference - - - - performance"
    ];

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="platform-profile", ATTR{name}=="amd-pmf", ATTR{profile}="performance"
    '';
  };
}
