# kanto

NixOS and k3s configuration for shared inference and applications. Kanto runs
Ollama, Lemonade, ComfyUI, Open WebUI, and Open Terminal on Vermilion.

See also [Hoenn](https://github.com/devon-systems/hoenn) for personal machines,
[Johto](https://github.com/devon-systems/johto) for the homelab, and
[Sinnoh](https://github.com/devon-systems/sinnoh) for production services.

## Architecture

| Host                                               | Role                                                           |
| -------------------------------------------------- | -------------------------------------------------------------- |
| [`vermilion`](nix/hosts/nixos/vermilion/README.md) | k3s server, Ollama, Lemonade with Strata, ComfyUI, and backups |

Open WebUI provides browser chat and an authenticated Chat Completions API.
It connects to Ollama and Lemonade on Vermilion. Open Terminal provides
persistent workspaces for code execution through WebUI. ComfyUI runs on the
host with a shared workspace and job queue.

Separate Tailscale ingress nodes provide private HTTPS access to Open WebUI and
ComfyUI. Vermilion uses local k3s networking.

Comin reconciles host configuration from `master`. Flux reconciles the
Kubernetes resources in `k8s/flux-system/` from the same branch.

See [Use Kanto models](docs/inference.md) for service access and client setup.

## Repository layout

```text
nix/
├── hosts/nixos/       Host configuration and hardware state
├── modules/           Host defaults and shared features
├── devShells.nix      Development tools
└── treefmt.nix        Formatting
k8s/                  Flux and application manifests
secrets/              SOPS-encrypted host secrets
keys/                 Public SOPS recipients
docs/                 Cluster operations and inference setup
scripts/              Maintenance tools
```

`flake.nix` recursively imports the Nix files under `nix/` and exposes
`nixosConfigurations.vermilion`. Kubernetes secrets live in `k8s/secrets/`.

## Development

Enter the pinned development shell with `nix develop`, or run `direnv allow` to
load it automatically. Then run:

```sh
nix fmt
nix flake check
nix build .#nixosConfigurations.vermilion.config.system.build.toplevel
```

After Kubernetes changes, run `just check-k8s`. Run `just` to list the other
maintenance commands.

## Deployment

Commit and push validated changes, then let Comin and Flux reconcile `master`.
Run `just flux-status` to inspect the cluster through the `kanto` context.
Renovate merges routine dependency updates after the required checks pass.

See [cluster operations](docs/kubernetes.md) for bootstrap, service sharing,
backups, recovery, and updates. For a new NixOS installation, follow the
[bootstrap guide](https://github.com/devon-systems/infra/blob/master/docs/nixos-bootstrap.md).

## Secrets

Run `just sops-bootstrap` once per machine to derive your local age key from
your SSH key. Then edit secrets with SOPS:

```sh
just sops-edit tailscale.yaml
just sops-edit k8s/secrets/tailscale-operator-values.sops.yaml
```

After changing `keys/`, run `just sops-rekey`. Commit `.sops.yaml` and all
re-encrypted files together. Never commit decrypted secrets or private keys.
Do not copy encrypted credentials or Flux identities from another cluster.
