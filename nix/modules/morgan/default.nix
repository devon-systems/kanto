_: {
  flake.nixosModules.morgan = {
    lib,
    pkgs,
    self,
    ...
  }: let
    keysDirectory = self + "/keys";
    morganKeyFiles = lib.pipe (builtins.readDir keysDirectory) [
      builtins.attrNames
      (lib.filter (file: lib.hasPrefix "morgan_" file && lib.hasSuffix ".pub" file))
      (lib.map (file: "${keysDirectory}/${file}"))
    ];
  in {
    programs.fish.enable = true;

    users.users.morgan = {
      description = "Morgan";
      hashedPassword = "!";
      isNormalUser = true;
      openssh.authorizedKeys.keyFiles = morganKeyFiles;
      shell = pkgs.fish;
      uid = 1001;
    };
  };
}
