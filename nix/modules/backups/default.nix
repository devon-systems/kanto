_: {
  flake.nixosModules.backups = {self, ...}: {
    sops.secrets = {
      restic-password = {
        sopsFile = self + "/secrets/restic.yaml";
        key = "PASSWORD";
      };
      rclone-b2 = {
        sopsFile = self + "/secrets/b2.yaml";
        key = "rclone_config";
      };
    };
  };
}
