# Talos Bootstrap Public Runbook

This runbook describes the reusable bootstrap flow for the public Talos
reference lab.

It intentionally excludes private command output, real addresses, and generated
secrets.

## Preconditions

- Proxmox access is available.
- OpenTofu is installed.
- `talosctl` is installed.
- Local `terraform.tfvars` files exist and are ignored by Git.
- Talos secrets are generated outside the repository.
- You have replaced all documentation-safe placeholder values.

## Provision VM Shells

From the root OpenTofu module:

```bash
cd tofu
tofu init
tofu fmt -recursive
tofu validate
tofu plan
tofu apply
```

For the Management Plane:

```bash
cd tofu/management
tofu init
tofu fmt -recursive
tofu validate
tofu plan
tofu apply
```

Review every plan before applying it.

## Generate Talos Secrets

Generate secrets outside the repository:

```bash
talosctl gen secrets --output-file ~/.config/ael-reference-lab/secrets.yaml
chmod 600 ~/.config/ael-reference-lab/secrets.yaml
```

Do not commit the secrets bundle.

## Generate Machine Configs

Use the public patches as inputs and write generated files outside Git or into
ignored local directories.

Example shape:

```bash
talosctl gen config \
  ael-reference-lab \
  https://192.0.2.10:6443 \
  --with-secrets ~/.config/ael-reference-lab/secrets.yaml \
  --config-patch @talos/patches/common.yaml \
  --config-patch @talos/patches/cluster.yaml \
  --config-patch @talos/patches/proxmox.yaml \
  --config-patch-control-plane @talos/patches/nodes/talos-cp-01.yaml \
  --output-dir ./talos/generated-local/cp01
```

Repeat with the matching node patch for each node.

## Apply And Bootstrap

Apply generated machine configs using your node addresses:

```bash
talosctl apply-config --insecure --nodes 192.0.2.11 --file ./talos/generated-local/cp01/controlplane.yaml
```

Bootstrap once, from the first control-plane node:

```bash
talosctl bootstrap --nodes 192.0.2.11 --endpoints 192.0.2.11
```

Retrieve kubeconfig after the API is available:

```bash
talosctl kubeconfig --nodes 192.0.2.11 --endpoints 192.0.2.11
```

## Install Cilium

Install Cilium using the public values as a starting point:

```bash
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --values talos/cilium/values.yaml
```

Apply LoadBalancer examples after adapting the address pool:

```bash
kubectl apply -f talos/cilium/lb-ipam-pool.yaml
kubectl apply -f talos/cilium/l2-announcement-policy.yaml
```

## Safety Rules

Never commit:

- generated Talos machine configs
- Talos secrets
- kubeconfig
- talosconfig
- OpenTofu state or plans
- raw bootstrap logs containing private topology
