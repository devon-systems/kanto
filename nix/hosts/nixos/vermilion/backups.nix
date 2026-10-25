_: {
  flake.nixosModules.vermilion = {config, ...}: let
    backupDefaults = {
      extraBackupArgs = ["--cleanup-cache"];
      initialize = true;
      passwordFile = config.sops.secrets.restic-password.path;
      rcloneConfigFile = config.sops.secrets.rclone-b2.path;
      pruneOpts = ["--keep-daily 7" "--keep-weekly 4" "--keep-monthly 3"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "3h";
      };
    };
  in {
    services.restic.backups = {
      k3s =
        backupDefaults
        // {
          paths = [
            "/var/lib/rancher/k3s/server/db/snapshots"
            "/var/lib/rancher/k3s/server/cred"
            "/var/lib/rancher/k3s/server/tls"
          ];
          repository = "rclone:b2:aly-backups/kanto/vermilion/k3s";
          backupPrepareCommand = ''
            ${config.services.k3s.package}/bin/k3s etcd-snapshot save &&
            ${config.services.k3s.package}/bin/k3s etcd-snapshot prune --snapshot-retention 5
          '';
        };
      k3s-local-path =
        backupDefaults
        // {
          paths = ["/var/lib/rancher/k3s/storage"];
          repository = "rclone:b2:aly-backups/kanto/vermilion/k3s-local-path";
        };
      lemonade =
        backupDefaults
        // {
          paths = ["/var/lib/lemonade/.config/lemonade"];
          repository = "rclone:b2:aly-backups/kanto/vermilion/lemonade";
        };
      comfyui =
        backupDefaults
        // {
          paths = ["/var/lib/comfyui"];
          exclude = [
            "/var/lib/comfyui/models"
            "/var/lib/comfyui/temp"
          ];
          repository = "rclone:b2:aly-backups/kanto/vermilion/comfyui";
        };
    };
  };
}
