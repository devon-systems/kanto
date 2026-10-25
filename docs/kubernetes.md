# Set up the Kanto cluster

Vermilion runs the Kanto k3s server and host-level inference. Comin reconciles
NixOS from `master`. Flux reconciles applications from `k8s/flux-system/`.
The initial cluster uses local k3s networking and host Tailscale access.

## Complete the hardware configuration

Capture Vermilion's nixos-facter report as
`nix/hosts/nixos/vermilion/facter.json`. Follow the shared
[NixOS bootstrap guide](https://github.com/alyraffauf/infra/blob/master/docs/nixos-bootstrap.md).
`disko.nix` identifies the verified Micron NVMe by its stable by-id path.
Review the partition layout before running Disko.

Keep Linux 6.18.4 or newer for the required Strix Halo KFD fixes. Start with
the device's default GPU memory settings, then check what the runtime can
allocate. AMD recommends a small BIOS reservation and a larger shared TTM/GTT
limit for supported Linux configurations. Record tested settings in the host
configuration. Do not copy another GPU's architecture override.

## Configure accounts and host recipients

Aly has passwordless sudo and SSH access through the existing `aly_*.pub` keys.
Aly uses the same SOPS-managed console password as Hoenn. SSH password
authentication is disabled. Morgan has no password or SSH key and cannot log in yet. To unlock SSH access, add her public key as
`keys/morgan_<device>.pub`. Her account remains a regular user.

Morgan's SSH keys do not become SOPS recipients. Kanto's host secrets use Aly's
administrator keys and the host keys in `keys/root_*.pub`. Kubernetes secrets
also include Kanto's own Flux age recipient.

Add Vermilion's SSH host public key as `keys/root_vermilion.pub`. Derive your
local age identity if needed and update recipients:

```sh
just sops-bootstrap
just sops-rekey
```

Commit `.sops.yaml` and every re-encrypted secret together.

## Fill in deployment credentials

Kanto shares the existing B2 credentials, host Tailscale enrollment key, and
Restic password, re-encrypted for its recipients. Its cluster token, Flux age
identity, WebUI signing key, and WebUI bootstrap password are independent.

Review the shared credentials and set the remaining values through SOPS:

```sh
just sops-edit tailscale.yaml
just sops-edit b2.yaml
just sops-edit k8s/secrets/tailscale-operator-values.sops.yaml
just sops-edit k8s/secrets/open-webui.sops.yaml
```

Set a host enrollment key in `tailscale-auth-key`. Set `rclone_config` to a
configuration with a `b2` remote and credentials for the backup destination.
The proposed backup prefix is `aly-backups/kanto/vermilion/`.

Create a separate Tailscale operator OAuth client. Set its `oauth.clientId`
and `oauth.clientSecret` in `stringData.values.yaml`. The operator uses
`tag:kanto-operator` and creates proxies with `tag:kanto-service`. Update the
tailnet policy through the existing Infra workflow to let the operator assign
its proxy tag. Follow the [operator installation guide](https://tailscale.com/docs/kubernetes-operator/install-operator).
Standalone ingress does not need Tailscale Service advertisement approval.

Set `WEBUI_ADMIN_EMAIL` to Aly's chosen WebUI login identity. Keep or replace
the generated bootstrap password. Signup is disabled. Open WebUI creates the
initial administrator from these credentials when its database is empty.
The administrator can create Morgan's application account afterward.

## Validate and install

Run the repository checks:

```sh
nix fmt
nix flake check
nix build .#nixosConfigurations.vermilion.config.system.build.toplevel
just check-k8s
```

A successful build does not capture the hardware report or validate enrollment
credentials. Finish those steps before deploying. Follow the shared bootstrap
guide for the first installation.

Publish the reviewed repository to `devon-systems/kanto` before enabling Git
reconciliation. CI uses the same `check-nix`, `build-nixos`, and `check-k8s`
workflows as the other clusters. Configure `CACHIX_AUTH_TOKEN` if CI should
upload build results to the existing cache. Configure required checks before
enabling Renovate automatic merges.

## Bootstrap Flux

Fetch the kubeconfig through ordinary OpenSSH:

```sh
just kubeconfig vermilion vermilion.narwhal-snapper.ts.net
export KUBECONFIG="$HOME/.kube/kanto"
```

The host firewall permits the Kubernetes API on its Tailscale interface.
Tailnet policy must also permit your administrator devices to access port 6443.
The kubeconfig contains administrator credentials and is written with mode 0600.

Create a repository-scoped SSH deploy identity:

```sh
ssh-keygen -t ed25519 -N '' -C kanto-flux -f ~/.ssh/kanto-flux
```

Register its public key as a read-only deploy key on `devon-systems/kanto`.
Bootstrap the checked-in Flux release:

```sh
just flux-bootstrap secrets/flux-age.yaml ~/.ssh/kanto-flux
just flux-status
```

The recipe checks that the age identity matches `keys/flux_k8s.pub`, installs
the checked-in controller manifests, and creates the Git and decryption
Secrets. It then applies the checked-in Flux sync resources. Namespaces
reconcile before secrets. The operator reconciles after its credentials, and
WebUI reconciles after the operator.

## Share browser and API access

The operator creates an individual node for the `openwebui` Ingress. Share
that node with Morgan through the Tailscale Machines page. Do not share the
operator controller node. Sharing Vermilion's host does not share the ingress
node automatically.

Both users open `https://openwebui.narwhal-snapper.ts.net`. HTTPS terminates
inside the operator's ingress proxy, which forwards to the WebUI Service.
The WebUI NetworkPolicy permits its application port from that proxy.

Share Vermilion's host node separately for Morgan's SSH access after adding her
key. Use ordinary OpenSSH with the Linux username `morgan`. Restrict her host
share to port 22 in the tailnet policy if she does not need Kubernetes API
connectivity. Kubernetes administration still requires separate credentials.

The existing tailnet policy grants broad connectivity. Adding a restrictive
grant does not override an existing wildcard allow. Review the complete policy
in Infra when narrowing shared access.

## Operate and recover

Use the same cluster-scoped recipes as Hoenn:

```sh
just flux-status
just reconcile open-webui
```

Comin polls `master` every ten minutes and activates host changes. The daily
NixOS upgrade job uses the committed lock, prepares the next boot, and does
not reboot. Flux polls Git every minute. Renovate follows the existing update
policy, including whole-release Flux updates and pinned container images.

Restic backs up etcd snapshots, k3s credentials, and local-path volumes daily.
The local-path backup is a file backup, not an application-consistent database
snapshot. Stop WebUI or capture a consistent SQLite backup before relying on
a particular database recovery point. Public model downloads are excluded.

Preserve `secrets/k3s.yaml`, `secrets/flux-age.yaml`, the WebUI signing key,
WebUI data, and the ingress proxy state in the k3s backup. Restoring the
existing proxy state retains the identity shared with Morgan. If that identity
is lost and recreated, share the replacement node again.

Follow the shared [k3s recovery guide](https://github.com/alyraffauf/infra/blob/master/docs/k3s-control-plane-recovery.md)
when restoring the cluster.
