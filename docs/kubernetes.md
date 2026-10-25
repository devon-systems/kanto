# Operate the Kanto cluster

Vermilion runs the Kanto k3s server and host-level inference services. Comin
reconciles NixOS from `master`; Flux reconciles the applications composed by
`k8s/flux-system/`.

## Validate and deploy a host

Use the pinned development shell. Run `nix fmt` and `nix flake check`, then
build each host affected by a Nix change:

```sh
nix build .#nixosConfigurations.vermilion.config.system.build.toplevel
```

Run `just check-k8s` after Kubernetes changes. Commit and push reviewed changes
for Comin and Flux to reconcile. For a manual host deployment, use
`blzrd switch vermilion`.

For a first installation or replacement machine, follow the shared
[NixOS bootstrap guide](https://github.com/devon-systems/infra/blob/master/docs/nixos-bootstrap.md).
Hardware reports, disk layouts, and host configuration live under
`nix/hosts/nixos/<host>/`.

## Bootstrap Flux

Use this procedure for initial setup or cluster recovery. Fetch the kubeconfig
through OpenSSH:

```sh
just kubeconfig vermilion vermilion.narwhal-snapper.ts.net
export KUBECONFIG="$HOME/.kube/kanto"
```

The recipe writes administrator credentials with mode 0600. The host firewall
permits the Kubernetes API on its Tailscale interface; tailnet policy must also
permit the administrator's device to reach port 6443.

Use a repository-scoped SSH deploy key registered as read-only on
`devon-systems/kanto`. With the private key stored at `~/.ssh/kanto-flux`:

```sh
just flux-bootstrap secrets/flux-age.yaml ~/.ssh/kanto-flux
just flux-status
```

The recipe verifies that the age identity matches `keys/flux_k8s.pub`, installs
the checked-in Flux controllers, and creates the Git and decryption Secrets.
It then applies the Flux sync resources. The dependencies in
`k8s/flux-system/` order namespaces, secrets, networking, and applications.

## Configure accounts and secrets

Aly has SSH access through `keys/aly_*.pub`, passwordless sudo, and a
SOPS-managed console password. SSH password authentication is disabled.
Morgan is a regular Linux user with a locked password. Add her SSH public key
as `keys/morgan_<device>.pub` to enable key-based login.

Linux and Open WebUI accounts are separate. WebUI signup is disabled. Its
bootstrap administrator credentials come from
`k8s/secrets/open-webui.sops.yaml` and apply when the database is empty.
Manage subsequent application accounts and API-key permissions in WebUI's
administration interface.

Host secrets use Aly's administrator keys and `keys/root_*.pub`. Kubernetes
secrets also include Kanto's Flux age recipient. Morgan's login keys do not
become SOPS recipients. After changing administrator or host keys, run
`just sops-rekey` and commit `.sops.yaml` with all re-encrypted secrets.

Edit credentials with `just sops-edit`; never copy encrypted secrets from
another cluster without re-encrypting them for Kanto. The cluster token,
Flux age identity, operator credentials, and WebUI signing key belong to Kanto.

## Expose and share services

The Tailscale operator uses `tag:kanto-operator` and creates proxies tagged
`tag:kanto-service`. Its OAuth credentials are in
`k8s/secrets/tailscale-operator-values.sops.yaml`. Manage the tailnet grants and
tag ownership through the shared Infra repository.

WebUI and ComfyUI use standalone operator Ingress nodes named `openwebui` and
`comfyui`. Keep these ingresses independent of a ProxyGroup so their individual
nodes remain shareable across tailnets. HTTPS terminates in each ingress proxy.

Share each service node with Morgan through the Tailscale Machines page.
Sharing the operator controller or Vermilion does not share those service
nodes. Share Vermilion separately if Morgan needs SSH access, then use ordinary
OpenSSH with the Linux username `morgan`.

Host Tailscale runs with `--netfilter-mode=off`; NixOS controls host port access.
Inference backend ports accept traffic through the local pod bridge. Clients
use WebUI authentication rather than connecting to the raw model servers.
Review the complete tailnet policy when narrowing access: an additional narrow
grant does not override an existing broad allow.

## Add workloads and nodes

Keep applications under `k8s/<app>/` and add their Flux Kustomizations under
`k8s/flux-system/`, including the required dependencies and resource lists.
Validate changes with `just check-k8s`.

Add NixOS hosts under `nix/hosts/nixos/<host>/` and compose the needed feature
modules in their `default.nix`, following Vermilion and the other clusters.
Add host keys, rekey secrets, and register the host with `blzrd`.

WebUI and the ComfyUI proxy currently select Vermilion and reach their host
backends through `status.hostIP`. Local-path volumes also remain on their
node. Adding another inference host requires explicit backend routing and
storage decisions; adding a NixOS configuration alone does not distribute
these services.

## Backups and recovery

Vermilion's Restic jobs back up etcd snapshots, k3s credentials, local-path
volumes, and ComfyUI state under `aly-backups/kanto/vermilion/`. Downloaded
ComfyUI models and temporary files are excluded. Ollama and Lemonade model
stores are not included in these jobs.

The local-path backup is a file backup, not an application-consistent database
snapshot. Stop WebUI or capture a consistent SQLite backup before relying on
a particular database recovery point. Open Terminal home directories are
persisted in the `open-terminal-home` local-path volume.

Preserve the cluster token, Flux age identity, WebUI signing key, application
data, and Tailscale ingress proxy state. Restoring the proxy state retains the
node identity shared with Morgan. If a proxy is recreated with a new identity,
share that replacement node again.

Follow the shared [k3s recovery guide](https://github.com/devon-systems/infra/blob/master/docs/k3s-control-plane-recovery.md).

## Automatic updates

Renovate opens dependency updates. Routine minor, patch, digest, pin, and lock
maintenance updates can automerge after the required flake, dev-shell, host
build, and Kubernetes checks pass. The `check-k8s` job validates manifests and
blocks merging when validation fails. Major updates remain manual.
`CACHIX_AUTH_TOKEN` enables CI uploads to the shared binary cache.

Comin polls `master` every ten minutes and activates host changes. The daily
NixOS upgrade job uses the committed lock and prepares the next boot without
rebooting. Flux polls Git every minute and reconciles Kubernetes changes.

Flux controller upgrades update the controllers, CRDs, and permissions as one
release. Keep customizations in `k8s/flux-system/kustomization.yaml`.
`just check-k8s` verifies the generated bundle against its declared release.

Use the cluster-scoped recipes to inspect or reconcile changes:

```sh
just flux-status
just reconcile
just reconcile open-webui
```

Git reconciliation updates configured packages and resources. It does not
update manually downloaded Ollama models, ComfyUI models, or custom nodes.
