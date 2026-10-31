_: {
  flake.nixosModules.vermilion = {
    config,
    lib,
    pkgs,
    ...
  }: let
    assets = import ./_package.nix {inherit pkgs;};
    lemonade = config.hardware.amd-npu.lemonade;
    stateDir = "/var/lib/halogen";
    settings = pkgs.writeText "halogen-launcher.json" (builtins.toJSON {
      rootfs = toString assets.rootfs;
      entrypoint = toString assets.entrypoint;
      bubblewrap = "${pkgs.bubblewrap}/bin/bwrap";
      model_cache = lemonade.cacheDir;
      state_dir = stateDir;
      environment = {
        HALOGEN_MODEL_ID = "Qwen3.8-Flash-Next-Halogen";
        HALOGEN_MTP_HEAD = toString assets.mtp;
        HALOGEN_TOKENIZER = toString assets.tokenizer;
        HALOGEN_VISION_TOWER = toString assets.vision;
        HALOGEN_KV_SLOTS = "2";
        HALOGEN_KV_POOL_POSITIONS = "262144";
        HALOGEN_MAX_TOK = "16384";
        HALOGEN_PROMPT_CACHE = "2";
        HALOGEN_COMPOSABLE_CONTEXT = "0";
        HALOGEN_THINKING_ANSWER_ROOM = "0";
        HALOGEN_TEMPERATURE = "0.6";
        HALOGEN_TOP_P = "0.95";
        HALOGEN_TOP_K = "20";
        # Keep the first rollout on the benchmarked in-memory cache policy.
        # Disk persistence can be enabled after validating I/O and unloads.
      };
    });
    launcher = pkgs.writeShellScript "halogen-lemond-shim" ''
      exec ${pkgs.python3}/bin/python3 ${./_launcher.py} --settings ${settings} "$@"
    '';
    reconcile = pkgs.writeShellApplication {
      name = "halogen-reconcile-alias";
      runtimeInputs = [pkgs.jq pkgs.coreutils];
      text = ''
        configDir="''${XDG_CONFIG_HOME:-$HOME/.config}/lemonade"
        models="$configDir/user_models.json"
        # The upstream module merges model declarations, so remove the old
        # registration after it has installed the separately named fallback.
        if [ -f "$models" ]; then
          jq 'del(."Qwen3.8-Flash-Next-Strata", ."user.Qwen3.8-Flash-Next-Strata")' "$models" > "$models.halogen"
          chmod --reference="$models" "$models.halogen"
          mv "$models.halogen" "$models"
        fi
        aliases="''${LEMONADE_CACHE_DIR:-${lemonade.cacheDir}/lemonade}/aliases.json"
        mkdir -p "$(dirname "$aliases")"
        [ -f "$aliases" ] || echo '{}' > "$aliases"
        # Use the public target ID: this Lemonade version does not advertise
        # aliases targeting a user-prefixed ID in its OpenAI model list.
        jq '. + {
          "Qwen3.8-Flash-Next-Strata": "Qwen3.8-Flash-Next-Halogen",
          "user.Qwen3.8-Flash-Next-Strata": "Qwen3.8-Flash-Next-Halogen"
        }' "$aliases" > "$aliases.halogen"
        chmod --reference="$aliases" "$aliases.halogen"
        mv "$aliases.halogen" "$aliases"
      '';
    };
  in {
    # The upstream NixOS module adds its overlay after the shared package set.
    nixpkgs.overlays = lib.mkAfter [
      (_final: prev: {
        lemonade = prev.lemonade.overrideAttrs (old: {
          patches = (old.patches or []) ++ [./_lemonade-recipe.patch];
        });
      })
    ];
    hardware.amd-npu = {
      strata.modelName = "Qwen3.8-Flash-Next-Strata-Fallback";
      lemonade = {
        settings.halogen.rocm_bin = "/etc/lemonade/backends/halogen-rocm";
        customModels."Qwen3.8-Flash-Next-Halogen" = {
          checkpoint = config.hardware.amd-npu.strata.model;
          source = "local_path";
          recipe = "halogen";
          labels = ["chat" "reasoning" "tool-calling" "vision"];
          recipe_options.ctx_size = 262144;
        };
      };
    };
    system.build.halogenIntegration = pkgs.linkFarm "halogen-integration" [
      {
        name = "settings.json";
        path = settings;
      }
      {
        name = "launcher";
        path = launcher;
      }
      {
        name = "reconcile";
        path = reconcile;
      }
      {
        name = "lemonade";
        path = pkgs.lemonade.override {withDesktopApp = lemonade.desktopApp.enable;};
      }
    ];
    environment.etc."lemonade/backends/halogen-rocm".source = launcher;
    systemd.tmpfiles.rules = ["d ${stateDir} 0700 ${lemonade.user} users -"];
    systemd.services.lemond.serviceConfig.ExecStartPre = lib.mkAfter ["${reconcile}/bin/halogen-reconcile-alias"];
  };
}
