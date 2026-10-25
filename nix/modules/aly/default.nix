_: {
  flake.nixosModules.aly = {
    config,
    lib,
    pkgs,
    self,
    ...
  }: let
    keysDirectory = self + "/keys";
    alyKeyFiles = lib.pipe (builtins.readDir keysDirectory) [
      builtins.attrNames
      (lib.filter (file: lib.hasPrefix "aly_" file && lib.hasSuffix ".pub" file))
      (lib.map (file: "${keysDirectory}/${file}"))
    ];
  in {
    nix.settings.trusted-users = lib.mkAfter ["aly"];
    programs.fish.enable = true;

    sops.secrets.aly-password = {
      neededForUsers = true;
      sopsFile = self + "/secrets/aly-password.yaml";
    };

    users.users.aly = {
      description = "Aly Raffauf";
      extraGroups = ["networkmanager" "wheel"];
      hashedPasswordFile = config.sops.secrets.aly-password.path;
      isNormalUser = true;
      openssh.authorizedKeys.keyFiles = alyKeyFiles;
      shell = pkgs.fish;
      uid = 1000;
    };
  };
}
