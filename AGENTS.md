# Work in Kanto

Kanto runs shared inference and infrastructure on Vermilion. Follow Hoenn's flake-parts/import-tree layout and the Comin, Flux, SOPS, and Renovate workflows shared with Hoenn and Johto.

- Hosts: `nix/hosts/nixos/<host>/`; features: `nix/modules/<feature>/`; NixOS defaults: `nix/modules/default/`
- Applications: `k8s/<app>/`; Flux Kustomizations: `k8s/flux-system/`
- Host secrets: `secrets/`; Kubernetes secrets: `k8s/secrets/`; public recipients: `keys/`

## Validate changes

Use the pinned development shell. Before committing, run `nix fmt` and `nix flake check`, then build every affected host:

```sh
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

For Kubernetes changes, update Kustomize resource lists and Flux dependencies together. Never reformat `k8s/flux-system/gotk-components.yaml`. Run `just check-k8s`; it renders the Flux graph and local Helm releases and validates remote Helm declarations without rendering their charts.

After `facter.json` changes, run:

```sh
nix run github:devon-systems/infra#generate-host-readmes
```

Never invent or copy hardware reports or edit generated host-spec sections.

## Commit messages

Use scoped Conventional Commits, such as `feat(open-webui): add shared chat and API access`.

## Deploy deliberately

Comin reconciles hosts and Flux reconciles applications from `master`. See `docs/kubernetes.md` for bootstrap and operations.

Manual deployment, forced reconciliation, and deployment-service restarts require an explicit user request. Never deploy to test. Run `just flux-bootstrap` only for requested initial installation or recovery.

## Keep secrets out of Git

Edit encrypted files with `just sops-edit`. Never print private keys or decrypted credentials, and never copy another cluster's encrypted credentials or Flux identity.

After recipient changes, run `just sops-rekey`; commit `.sops.yaml` with every re-encrypted file.

## Preserve shared access

Open WebUI and ComfyUI use standalone Tailscale operator Ingress nodes. Never add `tailscale.com/proxy-group` annotations to them. Keep each node shareable with Morgan on her own tailnet.
