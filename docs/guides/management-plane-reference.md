# Management Plane Reference Guide

This guide explains the public Management Plane foundation.

The Management Plane is a small Talos-based Kubernetes environment used to host
management and platform services separately from the primary workload cluster.

## What This Includes

The public reference includes:

- OpenTofu configuration for a Management Plane Talos VM
- Talos patches for the Management Plane node
- Cilium values for the Management Plane Kubernetes API endpoint
- a GitOps entrypoint for management platform resources

Generated configuration and runtime credentials are excluded.

## Reference Topology

The example Management Plane uses documentation-safe values:

| Component | Example Value |
| --- | --- |
| Management API VIP | `198.51.100.10` |
| Management node | `198.51.100.11` |
| Gateway / DNS placeholder | `198.51.100.1` |
| Pod CIDR | `10.45.0.0/16` |
| Service CIDR | `10.112.0.0/16` |

Replace these values with your own management network design.

## Build Flow

1. Review and adapt `tofu/management/environments/prod/terraform.example.tfvars`.
2. Create a local `terraform.tfvars` file and keep it untracked.
3. Supply `TF_VAR_proxmox_api_token` from your shell or secret manager.
4. Use OpenTofu to provision the Management Plane VM.
5. Generate Management Plane Talos secrets outside the repository.
6. Generate machine configs from `talos/management/patches/`.
7. Apply the generated config to the Management Plane node.
8. Bootstrap Kubernetes.
9. Install Cilium with `talos/management/cilium/values.yaml`.
10. Apply management GitOps resources after replacing placeholder repository URLs.

## Storage Boundary

The Management Plane OpenTofu example includes a dedicated data disk. This is
intended as a boundary for management platform state such as observability data.

Adapt disk sizing and storage placement to your own environment.

## Not Included

The public repository intentionally excludes:

- generated Talos configs
- Talos secrets and PKI material
- kubeconfig and talosconfig
- OpenTofu state and plans
- private operational evidence
