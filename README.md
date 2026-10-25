# kanto

Kanto runs shared inference and applications on NixOS and k3s. Flux deploys
applications, Comin deploys host configurations, and SOPS encrypts secrets.

For the homelab, see [johto](https://github.com/devon-systems/johto).
For personal machines and household services, see
[hoenn](https://github.com/devon-systems/hoenn).

## Architecture

| Host                                               | Role                                                           |
| -------------------------------------------------- | -------------------------------------------------------------- |
| [`vermilion`](nix/hosts/nixos/vermilion/README.md) | k3s server, Ollama, Lemonade with Strata, ComfyUI, and backups |

Open WebUI runs in Kubernetes and provides shared browser chat, individual
accounts, and an authenticated Chat Completions API. It connects to Ollama and
Lemonade on Vermilion. Open Terminal provides persistent workspaces for code
execution through WebUI. ComfyUI runs on the host with a shared workspace and
job queue.

Tailscale provides private HTTPS access through separate `openwebui` and
`comfyui` ingress nodes. Morgan can access these nodes from her own
tailnet through Tailscale sharing. Vermilion uses local k3s networking.
The WebUI and ComfyUI proxy pods run on the same host as their backends.

Comin reconciles host configuration from `master`. Flux reconciles Kubernetes
applications and secrets from `k8s/flux-system/`.

See [Use Kanto models](docs/inference.md) for service access and client setup.

## Repository layout

```text
nix/
├── hosts/nixos/       Per-host configuration and hardware state
├── modules/           Host defaults and feature modules
├── devShells.nix      Development tools
└── treefmt.nix        Formatting configuration
k8s/                  Flux, Kustomize, Helm, and application manifests
secrets/              SOPS-encrypted host secrets
keys/                 Public SSH keys and Flux age recipient
scripts/              Repository maintenance utilities
docs/                 Cluster operations and inference client setup
.github/workflows/    Flake checks and configuration builds
```

`flake.nix` recursively imports the modules under `nix/` and exposes
`nixosConfigurations.vermilion`. Each Kubernetes application has a directory under
`k8s/`. The resources in `k8s/flux-system/` define their reconciliation order.
Kubernetes secrets live in `k8s/secrets/`.

## Work locally

Enter the pinned development shell with `nix develop`, or use `direnv allow`
to load it automatically. From the repository root:

```sh
nix fmt
nix flake check
```

Run `just` to list maintenance commands. Use `just check-k8s` to validate
manifests and `just flux-status` to inspect deployments. The Flux recipes
target the `kanto` context, as the equivalent recipes do in Hoenn and Johto.

## Deploy changes

`blzrd` deploys the registered NixOS hosts. For example:

```sh
blzrd switch vermilion
```

`switch` activates the configuration and sets the boot default. `boot` sets
the boot default without activating it. Without a host name, `blzrd switch`
deploys every registered node.

Comin deploys host changes from `master`. Flux deploys Kubernetes workloads
from the same branch. Renovate follows the other clusters' update policy and
automatically merges routine updates after required checks pass.

See [Kanto cluster operations](docs/kubernetes.md) for bootstrap, service
sharing, backups, recovery, and automatic updates. First installations follow
the shared [NixOS bootstrap guide](https://github.com/devon-systems/infra/blob/master/docs/nixos-bootstrap.md).

## Edit secrets

SOPS encrypts secrets for the recipients in `.sops.yaml`. Public keys live in
`keys/`. To edit a host secret from the development shell:

```sh
just sops-edit tailscale.yaml
```

For Kubernetes secrets, pass the full path, such as
`just sops-edit k8s/secrets/tailscale-operator-values.sops.yaml`.
Use `just sops-bootstrap` once to derive your local age identity from your SSH
key. After changing recipients, run `just sops-rekey` and commit `.sops.yaml`
with the re-encrypted secrets.
