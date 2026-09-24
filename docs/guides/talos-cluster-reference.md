# Talos Cluster Reference Guide

This guide explains the public Talos cluster foundation of the AEL Reference
Lab.

The goal is to show the reproducible building blocks for a Talos-based
Kubernetes lab without publishing private topology, generated machine
configuration, or recovery material.

## What This Includes

The public reference includes:

- OpenTofu configuration for Talos node VMs on Proxmox
- Talos configuration patches for control-plane and worker nodes
- Cilium values and L2/IPAM examples
- a small GitOps cluster layout
- selected platform baseline manifests
- a sample `whoami` workload for validation

Generated Talos machine configs are not included because they contain cluster
secrets and PKI material.

## Reference Topology

The example workload cluster uses documentation-safe values:

| Component | Example Value |
| --- | --- |
| Kubernetes API VIP | `192.0.2.10` |
| Control plane nodes | `192.0.2.11-192.0.2.13` |
| Worker nodes | `192.0.2.21-192.0.2.23` |
| Gateway / DNS placeholder | `192.0.2.1` |
| LoadBalancer example pool | `203.0.113.200-203.0.113.220` |
| Pod CIDR | `10.244.0.0/16` |
| Service CIDR | `10.96.0.0/12` |

Replace these values with your own network plan before use.

## Build Flow

1. Review and adapt `tofu/environments/prod/terraform.example.tfvars`.
2. Create a local `terraform.tfvars` file and keep it untracked.
3. Supply the Proxmox API token through `TF_VAR_proxmox_api_token`.
4. Use OpenTofu to create the VM shell and download the Talos image.
5. Generate Talos secrets outside the repository.
6. Generate Talos machine configs from the public patches and your local secrets.
7. Apply machine configs to the nodes.
8. Bootstrap the first control-plane node.
9. Install Cilium using the public values as a starting point.
10. Apply the GitOps and platform manifests after adapting repository URLs and environment values.

## Talos Patch Layout

```text
talos/patches/common.yaml
talos/patches/cluster.yaml
talos/patches/proxmox.yaml
talos/patches/local-db-volume.yaml
talos/patches/nodes/
```

The node patches define node-specific hostnames, addresses, routes, and VIP
settings. The common and cluster patches define reusable baseline configuration.

## Cilium Layout

```text
talos/cilium/values.yaml
talos/cilium/l2-announcement-policy.yaml
talos/cilium/lb-ipam-pool.yaml
```

The public LoadBalancer pool uses `203.0.113.0/24` as a documentation-safe
example range. Replace it with a routable range in your lab network.

## GitOps Layout

```text
clusters/management/
platform/management/
```

The public Flux source URL is a placeholder. Replace it with your own Git
repository URL before applying the manifests.

## Not Included

The public repository intentionally excludes:

- Talos generated machine configs
- Talos secrets bundle
- kubeconfig
- talosconfig
- OpenTofu state and plans
- private validation evidence
- private recovery procedures

These artifacts must remain local to each lab.
