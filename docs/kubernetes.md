# Operate the Kanto cluster

Vermilion runs k3s and the inference services. Comin deploys NixOS from
`master`, and Flux deploys the applications defined in `k8s/flux-system/`.

## Validate and deploy the host

Run these checks in the pinned development shell:

```sh
nix fmt
nix flake check
nix build .#nixosConfigurations.vermilion.config.system.build.toplevel
```

After Kubernetes changes, also run `just check-k8s`.

Commit and push reviewed changes for Comin and Flux to reconcile. For a manual
host deployment, use `blzrd switch vermilion`.

For a first installation or replacement machine, follow the shared
[NixOS bootstrap guide](https://github.com/devon-systems/infra/blob/master/docs/nixos-bootstrap.md).
Hardware reports, disk layouts, and host configuration live under
`nix/hosts/nixos/<host>/`.

## Bootstrap Flux

Use this procedure for initial setup or cluster recovery.

### Fetch the kubeconfig

Fetch the kubeconfig over SSH:

```sh
just kubeconfig vermilion vermilion.narwhal-snapper.ts.net
export KUBECONFIG="$HOME/.kube/kanto"
```

The recipe writes administrator credentials with mode `0600`. The host firewall
permits the Kubernetes API on its Tailscale interface. The tailnet policy must
also permit your device to reach port `6443`.

### Install Flux

Use a read-only SSH deploy key registered on
`devon-systems/kanto`. If the private key is stored at `~/.ssh/kanto-flux`, run:

```sh
just flux-bootstrap secrets/flux-age.yaml ~/.ssh/kanto-flux
just flux-status
```

The recipe verifies that the age identity matches `keys/flux_k8s.pub`. It
installs the checked-in Flux controllers, creates the Git and decryption
Secrets, and applies the Flux sync resources. The dependencies in
`k8s/flux-system/` order namespaces, secrets, networking, and applications.

## Configure accounts and secrets

### Manage Linux accounts

Aly has passwordless sudo and a SOPS-managed console password. OpenSSH uses
`keys/aly_*.pub` for key authentication and rejects password authentication.
Tailscale SSH uses the tailnet policy.

Morgan is a regular Linux user with a locked password. Add her SSH public key
as `keys/morgan_<device>.pub` to enable key-based login.

### Manage WebUI accounts

Linux and Open WebUI accounts are separate. WebUI signup is disabled. Its
bootstrap administrator credentials come from
`k8s/secrets/open-webui.sops.yaml` and apply when the database is empty.

For each new WebUI user, use the administration interface:

1. Set the account role to **User**.
2. Add the account to the **API access** group if the user needs an API key.
   This group grants permission to create personal keys, not administrator
   access.
3. Grant the account read access to each model they should use.
4. Have the user refresh WebUI and confirm that the models and API-key option
   appear.

Grant users access to each new model.

WebUI stores groups, memberships, and model grants in its database. Restore or
recreate them after a database loss. For a fresh database, create **API access**
with the **API Keys** feature permission before adding members.

### Edit SOPS secrets

Host secrets use Aly's administrator keys and `keys/root_*.pub`. Kubernetes
secrets also include Kanto's Flux age recipient. Morgan's login keys do not
become SOPS recipients.

After changing administrator or host keys, run `just sops-rekey` and commit
`.sops.yaml` with all re-encrypted secrets.

Edit credentials with `just sops-edit`. Never copy encrypted secrets from
another cluster without re-encrypting them for Kanto. The cluster token, Flux
age identity, operator credentials, and WebUI signing key belong to Kanto.

## Expose and share services

### Configure Tailscale ingress

The Tailscale operator uses `tag:kanto-operator` and creates proxies tagged
`tag:kanto-service`. Its OAuth credentials are in
`k8s/secrets/tailscale-operator-values.sops.yaml`. Manage the tailnet grants and
tag ownership through the shared Infra repository.

WebUI and ComfyUI use standalone operator Ingress nodes named `openwebui` and
`comfyui`. Keep these ingresses independent of a ProxyGroup so their individual
nodes remain shareable across tailnets. HTTPS terminates in each ingress proxy.

### Share service nodes

Share each service node with Morgan through the Tailscale Machines page.
Sharing the operator controller or Vermilion does not share those service
nodes.

Vermilion uses Tailscale SSH for tailnet connections and OpenSSH keys for LAN
connections. Sharing Vermilion separately does not grant SSH access by itself.
The tailnet's SSH policy must permit the user and Linux account.

### Check network access

Host Tailscale runs with `--netfilter-mode=off`, so NixOS controls host port
access. Inference backend ports accept traffic through the local pod bridge.
Clients use WebUI authentication rather than connecting to the raw model
servers.

When restricting access, review all matching rules in the tailnet policy. A
narrow grant does not override an existing broad allow.

## Add workloads and nodes

### Add a workload

Keep applications under `k8s/<app>/` and add their Flux Kustomizations under
`k8s/flux-system/`, including the required dependencies and resource lists.
Validate changes with `just check-k8s`.

### Add a host

Add NixOS hosts under `nix/hosts/nixos/<host>/` and compose the needed feature
modules in their `default.nix`, following Vermilion and the other clusters. Add
host keys, rekey secrets, and register the host with `blzrd`.

WebUI and the ComfyUI proxy select Vermilion and reach their host
backends through `status.hostIP`. Local-path volumes also remain on their node.
For another inference host, configure its backend routing and storage.
Adding a NixOS configuration alone does not distribute these services.

## Restore backups

Vermilion's Restic jobs back up the following data under
`aly-backups/kanto/vermilion/`:

- etcd snapshots
- k3s credentials
- local-path volumes
- Lemonade configuration, including user-added model registrations and
  per-model settings
- ComfyUI state
- Prometheus and Loki data

The jobs exclude downloaded ComfyUI models, temporary files, and the Ollama and
Lemonade model stores.

Prometheus and Loki backups retain 7 daily, 4 weekly, and 12 monthly snapshots.

The local-path backup copies files without coordinating database writes. Stop
WebUI or capture a consistent SQLite backup before relying on a database
recovery point. Open Terminal stores home directories in
the `open-terminal-home` local-path volume.

Preserve the cluster token, Flux age identity, WebUI signing key, application
data, and Tailscale ingress proxy state. Restoring the proxy state retains the
node identity shared with Morgan. If you recreate a proxy with a new identity,
share the replacement node again.

Follow the shared
[k3s recovery guide](https://github.com/devon-systems/infra/blob/master/docs/k3s-control-plane-recovery.md).

## Check metrics and logs

Prometheus and Loki retain 30 days of data on Vermilion. Host Alloy collects
system metrics, journals, and Comin metrics. Kubernetes Alloy collects pod
logs, events, container metrics, workload state, and Flux metrics.

Prometheus scrapes Lemonade's native metrics for token usage, generation speed,
time to first token, prompt caching, and model residency. Host metrics include
AMD DRM GPU counters. Open WebUI sends HTTP and user-count metrics to Alloy
over OTLP. Ollama and ComfyUI currently have journal and host-resource coverage.

Use **Kanto Prometheus** and **Kanto Loki** in the shared Grafana on Canalave.
Follow the [observability guide](https://github.com/devon-systems/infra/blob/master/docs/observability.md)
to check collection and query the data.

## Manage automatic updates

### Review dependency updates

Renovate opens dependency updates. Routine minor, patch, digest, pin, and lock
maintenance updates can merge automatically after the required checks pass.
Major updates remain manual.

These checks cover the flake, development shell, host build, and Kubernetes
resources. The `check-k8s` job validates manifests and blocks merging when
validation fails. `CACHIX_AUTH_TOKEN` enables CI uploads to the shared binary
cache.

Flux controller upgrades update the controllers, CRDs, and permissions as one
release. Keep customizations in `k8s/flux-system/kustomization.yaml`.
`just check-k8s` verifies the generated bundle against its declared release.

### Check reconciliation

Comin polls `master` every ten minutes and activates host changes. The daily
NixOS upgrade job uses the committed lock and prepares the next boot without
rebooting. Flux polls Git every minute and reconciles Kubernetes changes.

Use the cluster-scoped recipes to inspect or reconcile changes:

```sh
just flux-status
just reconcile
just reconcile open-webui
```

Git reconciliation updates configured packages and resources. It does not
update manually downloaded Ollama models, ComfyUI models, or custom nodes.
