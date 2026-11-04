_: {
  perSystem = {
    treefmt.config = {
      programs = {
        alejandra.enable = true;
        deadnix.enable = true;
        prettier.enable = true;
        ruff-check.enable = true;
        ruff-format.enable = true;
        shellcheck.enable = true;
        shfmt.enable = true;
        statix.enable = true;
      };

      settings.excludes = [
        "secrets/**"
        "k8s/flux-system/gotk-components.yaml"
        "**/facter.json"
      ];
    };
  };
}
