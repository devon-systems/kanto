_: {
  flake.nixosModules.vermilion = {config, ...}: {
    services.k3s = {
      role = "server";
      clusterInit = true;
      nodeLabel = ["kanto.narwhal-snapper-ts.net/workload=inference"];
      disable = ["traefik" "servicelb"];
      extraFlags = ["--tls-san=vermilion.narwhal-snapper.ts.net"];
      extraKubeletConfig = {
        systemReserved = {
          cpu = "4";
          memory = "96Gi";
        };
        kubeReserved = {
          cpu = "500m";
          memory = "1Gi";
        };
        evictionHard = {
          "memory.available" = "1Gi";
          "nodefs.available" = "10%";
          "imagefs.available" = "15%";
          "nodefs.inodesFree" = "5%";
        };
      };
    };

    systemd.tmpfiles.rules = ["d /var/lib/rancher/k3s/storage 0755 root root -"];

    networking.firewall.interfaces = {
      cni0.allowedTCPPorts = [6443];
      ${config.services.tailscale.interfaceName}.allowedTCPPorts = [6443];
    };
  };
}
