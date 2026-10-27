_: {
  flake.nixosModules.observability = {
    config,
    lib,
    pkgs,
    ...
  }: let
    server =
      if config.services.prometheus.enable && config.services.loki.enable
      then "127.0.0.1"
      else "vermilion.narwhal-snapper.ts.net";
    lokiUrl = "http://${server}:3030/loki/api/v1/push";
  in {
    services.alloy = {
      enable = true;
      extraFlags = [
        "--storage.path=/var/lib/alloy/data-alloy"
        "--server.http.listen-addr=127.0.0.1:12345"
        "--disable-reporting"
      ];
    };

    systemd.services.observability-canary = {
      description = "Emit a log collection heartbeat";
      serviceConfig.Type = "oneshot";
      script = ''
        echo "observability_canary timestamp=$(${pkgs.coreutils}/bin/date +%s)"
      '';
    };
    systemd.timers.observability-canary = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = "1m";
      };
    };

    environment.etc."alloy/config.alloy".text =
      ''
        loki.write "default" {
          endpoint {
            url = "${lokiUrl}"
            remote_timeout = "10s"
            min_backoff_period = "500ms"
            max_backoff_period = "5m"
            max_backoff_retries = 20
            retry_on_http_429 = true
          }
        }

        loki.process "redact" {
          forward_to = [loki.write.default.receiver]
          stage.replace {
            expression = `(?i)\b(?:x-plex-token|plexonlinetoken|access_token|refresh_token|api[_-]?key|password|client_secret|authorization)["' ]*(?:[:=]|%3[dDaA])\s*"((?:\\.|[^"\\])*)"`
            replace = "[REDACTED]"
          }
          stage.replace {
            expression = `(?i)\b(?:x-plex-token|plexonlinetoken|access_token|refresh_token|api[_-]?key|password|client_secret|authorization)["' ]*(?:[:=]|%3[dDaA])\s*'((?:\\.|[^'\\])*)'`
            replace = "[REDACTED]"
          }
          stage.replace {
            expression = `(?i)\b(?:x-plex-token|plexonlinetoken|access_token|refresh_token|api[_-]?key|password|client_secret|authorization)["' ]*(?:[:=]|%3[dDaA])\s*(?:bearer\s+|basic\s+)?([^&\s"'<>]+)`
            replace = "[REDACTED]"
          }
        }

        loki.relabel "journal" {
          forward_to = []

          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }

          rule {
            source_labels = ["__journal__systemd_unit"]
            regex         = "(comin|observability-canary)[.]service"
            target_label  = "service"
            replacement   = "$1"
          }

          rule {
            source_labels = ["__journal__systemd_user_unit"]
            target_label  = "user_unit"
          }

          rule {
            source_labels = ["__journal_priority_keyword"]
            target_label = "level"
          }
        }

        loki.source.journal "read" {
          forward_to    = [loki.process.redact.receiver]
          relabel_rules = loki.relabel.journal.rules
          max_age       = "720h"
          labels        = {
            job  = "systemd-journal",
            host = "${config.networking.hostName}",
            node = "${config.networking.hostName}",
            cluster = "kanto",
            os = "linux",
          }
        }

        prometheus.exporter.unix "host" {
          enable_collectors = ["systemd", "drm", "textfile"]
          textfile {
            directory = "/var/lib/kanto-metrics"
          }
        }

        discovery.relabel "node" {
          targets = prometheus.exporter.unix.host.targets
          rule {
            target_label = "job"
            replacement = "node"
          }
          rule {
            target_label = "instance"
            replacement = "${config.networking.hostName}"
          }
          rule {
            target_label = "host"
            replacement = "${config.networking.hostName}"
          }
          rule {
            target_label = "os"
            replacement = "linux"
          }
        }

        prometheus.scrape "node" {
          targets = discovery.relabel.node.output
          job_name = "node"
          scrape_interval = "30s"
          forward_to = [prometheus.remote_write.kanto.receiver]
        }

        prometheus.exporter.self "host" {}

        discovery.relabel "alloy_self" {
          targets = prometheus.exporter.self.host.targets
          rule {
            target_label = "job"
            replacement = "alloy-host"
          }
          rule {
            target_label = "instance"
            replacement = "${config.networking.hostName}"
          }
          rule {
            target_label = "cluster"
            replacement = "kanto"
          }
        }

        prometheus.scrape "alloy_self" {
          targets = discovery.relabel.alloy_self.output
          job_name = "alloy-host"
          forward_to = [prometheus.remote_write.kanto.receiver]
        }

        prometheus.remote_write "kanto" {
          external_labels = {cluster = "kanto"}
          endpoint {
            url = "http://${server}:3020/api/v1/write"
            remote_timeout = "30s"
            queue_config {
              capacity = 10000
              min_shards = 1
              max_shards = 2
              max_samples_per_send = 2000
              batch_send_deadline = "5s"
              min_backoff = "30ms"
              max_backoff = "5s"
              retry_on_http_429 = true
            }
          }
          wal {
            truncate_frequency = "2h"
            min_keepalive_time = "5m"
            max_keepalive_time = "8h"
          }
        }
      ''
      + lib.optionalString config.services.comin.enable ''
        prometheus.scrape "comin" {
          targets = [{
            __address__ = "127.0.0.1:${toString config.services.comin.exporter.port}",
            instance    = "${config.networking.hostName}",
            host        = "${config.networking.hostName}",
            cluster     = "kanto",
          }]
          job_name        = "comin"
          scrape_interval = "30s"
          forward_to      = [prometheus.remote_write.kanto.receiver]
        }
      '';
  };
}
