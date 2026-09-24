# AEL Reference Lab

Public reference implementation for selected parts of the Architecture
Engineering Lab.

This repository contains sanitized infrastructure, automation, and operations
examples that accompany Architecture Engineering Lab articles. It is intended
for readers who want to inspect the implementation and reuse the patterns to
build a comparable lab.

## Repository Scope

This repository contains public reference material only. The private
Architecture Engineering Lab repository remains the system of record for real
lab implementation history, raw evidence, internal reviews, article drafts, and
environment-specific operations.

## Current Public Content

| Area | Path | Purpose |
| --- | --- | --- |
| Talos workload cluster IaC | `tofu/` | Example Proxmox-backed Talos Kubernetes cluster foundation. |
| Management Plane IaC | `tofu/management/` | Example Management Plane VM and data-disk foundation. |
| Talos cluster patches | `talos/patches/` | Public Talos patches for control-plane and worker nodes. |
| Management Plane patches | `talos/management/patches/` | Public Talos patches for the Management Plane. |
| Cilium configuration | `talos/cilium/`, `talos/management/cilium/` | Cilium and LoadBalancer examples for both clusters. |
| GitOps layout | `clusters/`, `platform/` | Minimal Flux/Kustomize structure for platform resources. |
| Platform examples | `kubernetes/` | Selected storage, alerting, and validation workload examples. |
| OpenTofu shared infrastructure | `tofu/shared-infrastructure/` | Example Proxmox-backed DNS/C3 infrastructure module. |
| DNS automation | `ansible/roles/technitium/` | Technitium DNS installation and authoritative zone automation. |
| DNS playbooks | `ansible/playbooks/` | Public playbooks for DNS baseline, inspection, reconciliation, and health gates. |
| Example inventory | `ansible/inventories/prod/` | Example inventory and variables using documentation-safe placeholder values. |
| Lifecycle helper | `scripts/lifecycle/c3-dns-lifecycle.sh` | DNS/C3 lifecycle orchestration helper. |
| Public guides | `docs/guides/` | Reproduction-oriented documentation. |
| Public runbooks | `docs/runbooks/` | Reusable operational procedures without private lab evidence. |

## Reference Topology

The example topology uses documentation-safe values:

- workload Kubernetes API VIP: `192.0.2.10`
- workload nodes: `192.0.2.11-192.0.2.23`
- Management Plane API VIP: `198.51.100.10`
- Management Plane node: `198.51.100.11`
- LoadBalancer example pool: `203.0.113.200-203.0.113.220`
- DNS cluster nodes: `dns-01`, `dns-02`
- DNS lab nodes: `dns-lab-01`, `dns-lab-02`
- example domain: `example.invalid`
- example infrastructure zone: `infra.example.invalid`
- example Kubernetes zone: `k8s.example.invalid`

Replace these values before using the examples in your own environment.

## Secret Handling

Do not commit local runtime values.

The examples intentionally exclude:

- Proxmox API token values
- Ansible Vault files
- local inventory files
- OpenTofu state and plan files
- generated Talos machine configuration
- Talos secrets and PKI material
- kubeconfig and talosconfig files

Use the provided `*.example.*` files as templates and keep local copies ignored
by Git.

## Getting Started

1. Review `docs/guides/talos-cluster-reference.md`.
2. Review `docs/guides/management-plane-reference.md`.
3. Review `docs/runbooks/talos-bootstrap-public-runbook.md`.
4. Adapt the OpenTofu example variables for your Proxmox environment.
5. Generate Talos secrets outside the repository.
6. Generate machine configs from the public Talos patches.
7. Bootstrap the workload cluster and Management Plane.
8. Review `docs/guides/dns-c3-reference.md` for DNS/C3 automation.

This repository is deliberately conservative: examples are promoted only after
sanitization and explicit review.
