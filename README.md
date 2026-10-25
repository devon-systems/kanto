# kanto

Declarative infrastructure for shared inference and applications. Kanto combines
NixOS, k3s, Flux, and SOPS to manage hosts, model servers, private service access,
and backups.

For the homelab, see [johto](https://github.com/devon-systems/johto).
For personal machines and household services, see
[hoenn](https://github.com/devon-systems/hoenn).

## Architecture

| Host                                               | Role                                                      |
| -------------------------------------------------- | --------------------------------------------------------- |
| [`vermilion`](nix/hosts/nixos/vermilion/README.md) | k3s server, Ollama, Lemonade/Strata, ComfyUI, and backups |

Open WebUI runs in Kubernetes and provides shared browser chat, individual
accounts, and an authenticated Chat Completions API. It connects to Ollama and
Lemonade on Vermilion. Open Terminal provides persistent workspaces for code
execution through WebUI. ComfyUI runs on the host with a shared workspace and
job queue.

Tailscale provides private HTTPS access through separate `openwebui` and
`comfyui` ingress nodes. These nodes can be shared with Morgan on her own
tailnet. Vermilion uses local k3s networking; the WebUI and ComfyUI proxy pods
run on the same host as their backends.

Comin reconciles host configuration from `master`. Flux reconciles Kubernetes
applications and secrets from `k8s/flux-system/`.

See [Use Kanto models](docs/inference.md) for service access and client setup.
For manual client configuration, see [Connect OpenCode and Hermes to Kanto](docs/agent-clients.md).

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
`nixosConfigurations.vermilion`. Kubernetes applications are grouped by
service under `k8s/`; `k8s/flux-system/` defines their reconciliation order.
Kubernetes secrets live in `k8s/secrets/`.

## Work locally

Enter the pinned development shell with `nix develop`, or use `direnv allow`
to load it automatically. From the repository root:

```sh
nix fmt
nix flake check
```

Run `just` to list maintenance commands. The Kubernetes recipes match Hoenn
and Johto: `just check-k8s` validates manifests, `just reconcile` reconciles
the Flux root, `just reconcile <name>` reconciles a workload, and
`just flux-status` shows reconciliation status. Flux recipes explicitly target
the `kanto` context.

## Deployment

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

## Secrets

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
