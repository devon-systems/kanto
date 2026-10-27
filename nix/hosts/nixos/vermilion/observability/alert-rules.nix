_: {
  flake.nixosModules.vermilion = let
    alert = {
      name,
      expr,
      duration,
      severity,
      summary,
      description,
    }: {
      alert = name;
      inherit expr;
      for = duration;
      labels = {
        cluster = "kanto";
        inherit severity;
      };
      annotations = {inherit summary description;};
    };
  in {
    # Sinnoh's Alertmanager on Canalave delivers alerts for every cluster.
    services.prometheus = {
      globalConfig.external_labels.cluster = "kanto";
      alertmanagers = [{static_configs = [{targets = ["canalave.narwhal-snapper.ts.net:3040"];}];}];
      rules = [
        (builtins.toJSON {
          groups = [
            {
              name = "kanto-backups";
              interval = "30s";
              rules = [
                (alert {
                  name = "HostBackupFailed";
                  expr = ''restic_backup_last_run_success{job="node"} == 0'';
                  duration = "5m";
                  severity = "warning";
                  summary = "A host backup failed";
                  description = "The latest {{ $labels.backup }} backup on {{ $labels.instance }} failed. Check restic-backups-{{ $labels.backup }}.service and retry after correcting the failure.";
                })
                (alert {
                  name = "HostBackupOverdue";
                  expr = ''time() - (restic_backup_last_success_timestamp_seconds{job="node"} > 0) > 48 * 60 * 60'';
                  duration = "15m";
                  severity = "critical";
                  summary = "A host backup is overdue";
                  description = "The {{ $labels.backup }} backup on {{ $labels.instance }} has not succeeded in over 48 hours. Check its timer and restic service.";
                })
                (alert {
                  name = "HostBackupSuccessMissing";
                  expr = ''
                    restic_backup_job_info{job="node"}
                    unless on (instance, backup)
                    (restic_backup_last_success_timestamp_seconds{job="node"} > 0)
                  '';
                  duration = "48h";
                  severity = "warning";
                  summary = "A host backup has no recorded success";
                  description = "The {{ $labels.backup }} backup on {{ $labels.instance }} has had no valid success timestamp for 48 hours. Check the backup and its metrics reporter.";
                })
                (alert {
                  name = "HostBackupMetricsMissing";
                  expr = ''absent(restic_backup_job_info{job="node"})'';
                  duration = "1h";
                  severity = "warning";
                  summary = "Kanto reports no backup metrics";
                  description = "No restic_backup_job_info series has arrived for an hour, so backup failures would go unnoticed. Check the backup metrics seed unit and the Alloy textfile collector on vermilion.";
                })
              ];
            }
          ];
        })
      ];
    };
  };
}
