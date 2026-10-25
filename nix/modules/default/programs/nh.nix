_: {
  flake.nixosModules.default = {pkgs, ...}: {
    environment = {
      systemPackages = with pkgs; [
        git
      ];

      variables = let
        FLAKE = "github:devon-systems/kanto";
      in {
        inherit FLAKE;
        NH_FLAKE = FLAKE;
      };
    };

    programs.nh = {
      enable = true;
    };
  };
}
