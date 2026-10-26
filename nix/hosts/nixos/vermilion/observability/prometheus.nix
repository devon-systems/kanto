_: {
  flake.nixosModules.vermilion = {
    services.prometheus = {
      enable = true;
      port = 3020;
      retentionTime = "30d";
      extraFlags = ["--web.enable-remote-write-receiver"];
      globalConfig = {
        scrape_interval = "30s";
        evaluation_interval = "30s";
      };
      scrapeConfigs = map (scrape:
        scrape
        // {
          relabel_configs =
            (scrape.relabel_configs or [])
            ++ [
              {
                target_label = "cluster";
                replacement = "kanto";
              }
            ];
        }) [
        {
          job_name = "lemonade";
          static_configs = [
            {
              targets = ["127.0.0.1:13305"];
              labels = {
                instance = "vermilion";
                host = "vermilion";
                os = "linux";
              };
            }
          ];
        }
        {
          job_name = "prometheus";
          static_configs = [
            {
              targets = ["127.0.0.1:3020"];
              labels = {
                instance = "vermilion";
                host = "vermilion";
                os = "linux";
              };
            }
          ];
        }
        {
          job_name = "loki";
          static_configs = [
            {
              targets = ["127.0.0.1:3030"];
              labels = {
                instance = "vermilion";
                host = "vermilion";
                os = "linux";
              };
            }
          ];
        }
      ];
    };
  };
}
