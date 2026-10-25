{inputs, ...}: {
  flake.nixosModules.strata = {pkgs, ...}: let
    sources = import (inputs.nix-amd-ai + "/pkgs/strata/sources.nix");
    prepare = pkgs.callPackage (inputs.nix-amd-ai + "/pkgs/strata/prepare.nix") {
      strataPkg = pkgs.strata;
      strataRev = sources.strata.rev;
      ggmlRev = sources.ggml.rev;
    };
  in {
    users.groups.strata = {};
    users.users.strata = {
      isSystemUser = true;
      group = "strata";
      extraGroups = ["render" "video"];
      home = "/var/lib/strata";
    };

    systemd.services.strata-prepare = {
      description = "Prepare Strata model artifacts";
      before = ["strata.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "strata";
        Group = "strata";
        StateDirectory = "strata";
        ExecStart = "${prepare}/bin/strata-prepare";
        TimeoutStartSec = "infinity";
        RemainAfterExit = true;
      };
    };

    systemd.services.strata = {
      description = "Strata inference API";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      requires = ["strata-prepare.service"];
      after = ["network-online.target" "strata-prepare.service"];
      environment.PYTHONUNBUFFERED = "1";
      serviceConfig = {
        User = "strata";
        Group = "strata";
        StateDirectory = "strata";
        WorkingDirectory = "/var/lib/strata";
        ExecStart = "${pkgs.strata}/bin/strata-server --engine strata --config /etc/strata/config.json --host 0.0.0.0 --port 8095 --lazy --idle-unload 300";
        Restart = "on-failure";
        RestartSec = 10;
        LimitMEMLOCK = "infinity";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    networking.firewall.interfaces.cni0.allowedTCPPorts = [8095];
  };
}
