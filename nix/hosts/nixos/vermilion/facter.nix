_: {
  flake.nixosModules.vermilion = {
    lib,
    self,
    ...
  }: let
    report = self + "/nix/hosts/nixos/vermilion/facter.json";
    hasReport = builtins.pathExists report;
  in {
    hardware.facter.reportPath = lib.mkIf hasReport report;
    boot.initrd.availableKernelModules = lib.mkIf (!hasReport) ["xhci_pci" "nvme" "usb_storage" "usbhid"];
  };
}
