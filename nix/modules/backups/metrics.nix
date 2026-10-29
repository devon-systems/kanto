{inputs, ...}: {
  flake.nixosModules.backups = {
    config,
    lib,
    pkgs,
    ...
  }: let
    directory = "/var/lib/kanto-metrics";
    jobs = builtins.attrNames config.services.restic.backups;
    reporter = inputs.dvnpkgs.packages.${pkgs.stdenv.hostPlatform.system}.backup-metrics;
    command = "${lib.getExe reporter} --directory ${directory}";
  in {
    systemd.tmpfiles.rules = ["d ${directory} 0755 root root -"];

    systemd.services = lib.mkMerge [
      (lib.mapAttrs' (job: _:
        lib.nameValuePair "restic-backups-${job}" {
          onSuccess = ["kanto-backup-metrics-${job}.service"];
          onFailure = ["kanto-backup-metrics-${job}.service"];
          serviceConfig.ExecStartPre = lib.mkBefore ["-${command} --start ${lib.escapeShellArg job}"];
        })
      config.services.restic.backups)
      (lib.listToAttrs (map (job:
        lib.nameValuePair "kanto-backup-metrics-${job}" {
          description = "Publish completed backup result for ${job}";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${command} ${lib.escapeShellArg job}";
          };
        })
      jobs))
      {
        kanto-backup-metrics-seed = {
          description = "Initialize backup inventory and recover interrupted results";
          wantedBy = ["multi-user.target"];
          after = ["systemd-tmpfiles-setup.service"];
          before = ["alloy.service"] ++ map (job: "restic-backups-${job}.service") jobs;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${command} --seed ${lib.escapeShellArgs jobs}";
          };
        };
      }
    ];
  };
}
