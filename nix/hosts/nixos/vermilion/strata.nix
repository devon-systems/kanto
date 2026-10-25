{inputs, ...}: {
  flake.nixosModules.vermilion = {pkgs, ...}: let
    sources = import (inputs.nix-amd-ai + "/pkgs/strata/sources.nix");
    model = sources.model.quants.UD-IQ4_XS;
    modelDir = "/var/lib/strata/models";
    modelPath = "${modelDir}/${model.file}";
    state = "/var/lib/strata";
    settings = {
      exe = "${pkgs.strata}/bin/strata";
      cwd = state;
      tokenizer = "${state}/pack/tokenizer";
      model_name = "Qwen3.8-Flash-Next-UD-IQ4_XS-Strata";
      backend = "hip";
      log = "${state}/engine.log";
      sampling = {
        temperature = 0.6;
        top_p = 0.95;
        top_k = 20;
      };
      args = [
        "--pack"
        "${state}/pack"
        "--native"
        modelPath
        "--mtp"
        "${state}/mtp/rt"
        "--max-context"
        "131072"
        "--kv"
        "int8"
        "--mmap-experts"
        "--expert-cache"
        "20000"
      ];
    };
  in {
    environment.etc."strata/config.json".source =
      (pkgs.formats.json {}).generate "strata-config.json" settings;

    systemd.services.strata-prepare = {
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = [pkgs.python3Packages.huggingface-hub];
      preStart = ''
        hf download ${model.repo} --revision ${model.rev} \
          --include 'UD-IQ4_XS/*' --local-dir ${modelDir}
      '';
      environment.STRATA_MODEL = modelPath;
    };
  };
}
