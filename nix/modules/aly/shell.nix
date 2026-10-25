_: {
  flake.nixosModules.aly = {pkgs, ...}: {
    users.users.aly.packages = with pkgs; [
      age
      bun
      codex
      duf
      dust
      gh
      imagemagick
      jq
      just
      lazygit
      nodejs
      opencode
      ripgrep
      uv
    ];
  };
}
