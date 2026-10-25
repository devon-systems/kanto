# Work in Kanto

Kanto runs shared inference and infrastructure on Vermilion. Follow Hoenn's
flake-parts and import-tree module layout. Use the Comin, Flux, SOPS, and
Renovate workflows shared by Hoenn and Johto.

Keep host state in `nix/hosts/nixos/<host>/`, reusable features in
`nix/modules/<feature>/`, and common NixOS defaults in `nix/modules/default/`.
Keep applications in `k8s/<app>/` and their
Flux Kustomizations in `k8s/flux-system/`.

## Check a change

Use the pinned development shell. Run `nix fmt` and `nix flake check` before
committing. Build each host affected by a Nix change:

```sh
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

Run `just check-k8s` after Kubernetes changes. Update the relevant Kustomize
resource lists and Flux dependencies together. Do not reformat
`k8s/flux-system/gotk-components.yaml`. The Kubernetes check renders the Flux
graph and local Helm releases. It validates remote Helm declarations without
rendering their charts.

After adding or changing a host's `facter.json`, run the shared host README
generator:

```sh
nix run github:devon-systems/infra#generate-host-readmes
```

Do not invent hardware reports, copy another host's report, or hand-edit the
generated host-spec sections.

## Write commit messages

Use scoped Conventional Commits, such as
`feat(open-webui): add shared chat and API access`.

## Deploy deliberately

Comin reconciles host configuration from `master`. Flux reconciles applications
from `master`. Follow [cluster operations](docs/kubernetes.md) for bootstrap
and operations.

Manual deployment, forced reconciliation, and restarts of deployment services
require an explicit user request. Never deploy to test a configuration. Run
`just flux-bootstrap` only for a requested initial installation or recovery.

## Keep secrets out of Git

Keep host secrets in `secrets/`, Kubernetes secrets in `k8s/secrets/`, and public
recipients in `keys/`. Use `just sops-edit` to edit encrypted files. Run
`just sops-rekey` when recipients change, and commit `.sops.yaml` with every
re-encrypted file. Never copy another cluster's encrypted credentials or Flux
identity into Kanto. Never print private keys or decrypted credentials.

## Preserve shared access

Open WebUI and ComfyUI use standalone Tailscale operator Ingress nodes. Do not
add `tailscale.com/proxy-group` annotations to them. Keep each node shareable
with Morgan on her own tailnet.
