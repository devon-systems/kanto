_: {
  flake.nixosModules.vermilion = {
    config,
    lib,
    pkgs,
    ...
  }: let
    lemonade = config.hardware.amd-npu.lemonade;
    podmanConfig = pkgs.writeText "lemond-containers.conf" ''
      [engine]
      cgroup_manager = "cgroupfs"
      runtime = "crun"
    '';
    reconcile = pkgs.writeShellApplication {
      name = "halogen-reconcile-alias";
      runtimeInputs = [pkgs.jq pkgs.coreutils];
      text = ''
        configDir="''${XDG_CONFIG_HOME:-$HOME/.config}/lemonade"
        config="$configDir/config.json"
        if [ -f "$config" ]; then
          jq 'if .halogen.rocm_bin == "/etc/lemonade/backends/halogen-rocm"
            then del(.halogen.rocm_bin) else . end' "$config" > "$config.halogen"
          chmod --reference="$config" "$config.halogen"
          mv "$config.halogen" "$config"
        fi
        models="$configDir/user_models.json"
        # The module merges persisted models. Drop obsolete registrations
        # so they cannot shadow the built-in Halogen model or the Strata alias.
        if [ -f "$models" ]; then
          jq 'del(
            ."Qwen3.8-Flash-Next-Strata", ."user.Qwen3.8-Flash-Next-Strata",
            ."Qwen3.8-Flash-Next-Halogen", ."user.Qwen3.8-Flash-Next-Halogen"
          )' "$models" > "$models.halogen"
          chmod --reference="$models" "$models.halogen"
          mv "$models.halogen" "$models"
        fi
        aliases="''${LEMONADE_CACHE_DIR:-${lemonade.cacheDir}/lemonade}/aliases.json"
        mkdir -p "$(dirname "$aliases")"
        [ -f "$aliases" ] || echo '{}' > "$aliases"
        jq '. + {
          "Qwen3.8-Flash-Next-Strata": "Qwen3.8-Flash-Next-Halogen",
          "user.Qwen3.8-Flash-Next-Strata": "Qwen3.8-Flash-Next-Halogen"
        }' "$aliases" > "$aliases.halogen"
        chmod --reference="$aliases" "$aliases.halogen"
        mv "$aliases.halogen" "$aliases"
      '';
    };
  in {
    virtualisation.podman.enable = true;
    users.users.${lemonade.user}.autoSubUidGidRange = true;

    hardware.amd-npu = {
      strata.modelName = "Qwen3.8-Flash-Next-Strata-Fallback";
      lemonade.models = ["Qwen3.8-Flash-Next-Halogen"];
    };

    system.build.halogenReconcile = reconcile;
    systemd.services.lemond = {
      path = ["/run/wrappers" config.virtualisation.podman.package pkgs.shadow];
      environment = {
        CONTAINERS_CONF_OVERRIDE = toString podmanConfig;
        XDG_RUNTIME_DIR = "/run/lemond";
      };
      serviceConfig = {
        Delegate = true;
        ExecStartPre = lib.mkAfter ["${reconcile}/bin/halogen-reconcile-alias"];
      };
    };
  };
}
