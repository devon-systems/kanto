_: {
  flake.nixosModules.lemonade = {
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
  };
}
