# Work in Kanto

Kanto is the shared inference and infrastructure cluster. Vermilion is its first
NixOS host. Follow Hoenn's flake-parts and import-tree module layout and the
Comin, Flux, SOPS, and Renovate workflows used by Hoenn and Johto.

Keep host state in `nix/hosts/nixos/<host>/`, reusable features in
`nix/modules/<feature>/`, common NixOS
defaults in `nix/modules/default/`. Keep applications in `k8s/<app>/` and their
Flux Kustomizations in `k8s/flux-system/`.

## Check a change

Use the pinned development shell. Before committing, run:

```sh
nix fmt
nix flake check
nix build .#nixosConfigurations.vermilion.config.system.build.toplevel
just check-k8s
```

Update the relevant Kustomize resource lists and Flux dependencies together.
Do not reformat `k8s/flux-system/gotk-components.yaml`. The Kubernetes check
renders the Flux graph and local Helm releases. It validates remote Helm
declarations without rendering their charts.

Use scoped Conventional Commits, such as
`feat(open-webui): add shared chat and API access`.

## Deploy deliberately

Comin reconciles host configuration from `master`. Flux reconciles applications
from `master`. Follow `docs/kubernetes.md` for bootstrap and operations.

This initial repository is a mock. Capture Vermilion's nixos-facter report and
configure its actual NVMe identifier before installing. Do not invent hardware
reports or copy another host's report. Run the shared host README generator
after adding or changing `facter.json`.

Manual deployment, forced reconciliation, and restarts of deployment services
require an explicit user request. Never deploy to test a configuration. Run
`just flux-bootstrap` only for a requested initial installation or recovery.

## Keep secrets out of Git

Keep host secrets in `secrets/`, Kubernetes secrets in `k8s/secrets/`, and public
recipients in `keys/`. Use `just sops-edit` to edit encrypted files. Run
`just sops-rekey` when recipients change, and commit `.sops.yaml` with every
re-encrypted file. Never copy another cluster's encrypted credentials or Flux
identity into Kanto. Never print private keys or decrypted credentials.

Open WebUI uses a standalone Tailscale operator Ingress. Do not add a
`tailscale.com/proxy-group` annotation to it. Its individual ingress node must
remain shareable with Morgan on her own tailnet.
