## AEL Reference Lab

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
| Image engineering | `packer/debian-13-proxmox/` | Reproducible Debian 13 / Proxmox base-image build, sanitization, acceptance implementation, and release metadata. |
| OpenTofu shared infrastructure | `tofu/shared-infrastructure/` | Example Proxmox-backed DNS shared-infrastructure module. |
| DNS automation | `ansible/roles/technitium/` | Technitium DNS installation and authoritative zone automation. |
| DNS playbooks | `ansible/playbooks/` | Public playbooks for DNS baseline, inspection, reconciliation, and health gates. |
| Example inventory | `ansible/inventories/prod/` | Example inventory and variables using documentation-safe placeholder values. |
| Lifecycle helper | `scripts/lifecycle/dns-lifecycle-controller.sh` | Guarded DNS lifecycle-control helper. |
| Public guides | `docs/guides/` | Reproduction-oriented DNS, image-engineering, Talos, and Management Plane documentation. |
| Public runbooks | `docs/runbooks/` | Reusable operational procedures without private lab evidence. |
| Ingress platform | `kubernetes/ingress/traefik/` | Traefik LoadBalancer, ingress, dashboard, and metrics reference configuration. |
| TLS platform | `kubernetes/tls/cert-manager/` | cert-manager and ACME DNS-01 reference configuration. |
| Backup and recovery | `kubernetes/backup/velero/` | Velero, node-agent/Kopia, external object storage, monitoring, and restore-test reference. |
| Monitoring and alerting | `kubernetes/monitoring/` | Prometheus, Grafana, Alertmanager, platform alerts, and secured platform UI reference configuration. |
| Management GitOps | `clusters/management/`, `platform/management/` | Flux bootstrap and Management Plane reconciliation reference. |
| External NFS storage | `kubernetes/storage/nfs/` | NFS CSI StorageClass and RWX validation workload for externally backed persistent data. |
| Stateful application | `kubernetes/apps/nextcloud/` | Nextcloud reference workload combining local storage, shared NFS data, PostgreSQL, Redis, TLS, and backup intent. |

## Reference Topology

The example topology uses documentation-safe values:

- workload Kubernetes API VIP: `192.0.2.10`
- workload nodes: `192.0.2.11-192.0.2.23`
- Management Plane API VIP: `198.51.100.10`
- Management Plane node: `198.51.100.11`
- LoadBalancer example pool: `203.0.113.200-203.0.113.220`
- DNS cluster nodes: `dns-01`, `dns-02`
- DNS lab nodes: `dns-lab-01`, `dns-lab-02`
- example domain: `example.com`
- example infrastructure zone: `infra.example.com`
- example Kubernetes zone: `k8s.example.com`

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
by Git. For DNS lifecycle control, `ansible/inventories/prod/group_vars/all/vault.example.yml`
defines the required Ansible secret variable names without containing secret values.

## Explore the Reference Lab

Start with the architecture area that matches the problem you are investigating:

| Interest | Start here |
| --- | --- |
| Talos and Kubernetes foundation | [Talos Cluster Reference](docs/guides/talos-cluster-reference.md) |
| Application validation and local persistent storage | [Application & Local Storage Reference](docs/guides/application-and-local-storage-reference.md) |
| Separate management failure domain | [Management Plane Reference](docs/guides/management-plane-reference.md) |
| Management Plane host recovery | [Management Plane Proxmox Host Recovery](docs/runbooks/management-plane/proxmox-host-recovery.md) |
| Shared-infrastructure DNS | [DNS Lifecycle Control Reference](docs/guides/dns-lifecycle-control-reference.md) |
| Reproducible VM image engineering and bootstrap dependencies | [Image Engineering Reference](docs/guides/image-engineering-reference.md) and `packer/debian-13-proxmox/` |
| Controlled change across the DNS redundancy boundary | [DNS Lifecycle Control Runbook](docs/runbooks/dns-lifecycle-control-runbook.md) |
| Ingress, HTTPS, and certificate lifecycle | [Ingress & TLS Reference](docs/guides/ingress-and-tls-reference.md) |
| Backup, restore, and recoverability validation | [Backup & Recovery Reference](docs/guides/backup-and-recovery-reference.md) |
| Monitoring, dashboards, and platform alerting | [Monitoring & Alerting Reference](docs/guides/monitoring-and-alerting-reference.md) |
| Management Plane GitOps and reconciliation | [Management GitOps Reference](docs/guides/management-gitops-reference.md) |
| External shared storage and NFS CSI | [NFS Storage Reference](docs/guides/nfs-storage-reference.md) |
| Stateful application architecture | [Stateful Application Reference](docs/guides/stateful-application-reference.md) |

The accompanying Architecture Engineering Lab articles explain the architecture decisions and experiments behind these reference implementations. The implementation repository is intentionally narrower than the private engineering system of record.

## Architecture Engineering Lab Articles

The Architecture Engineering Lab series is published on Medium:

- https://medium.com/@mmelchers75

## Build the Complete Reference Lab

1. Review `docs/guides/talos-cluster-reference.md`.
2. Review `docs/guides/management-plane-reference.md`.
3. Review `docs/runbooks/talos-bootstrap-public-runbook.md`.
4. Adapt the OpenTofu example variables for your Proxmox environment.
5. Generate Talos secrets outside the repository.
6. Generate machine configs from the public Talos patches.
7. Bootstrap the workload cluster and Management Plane.
8. Review `docs/guides/application-and-local-storage-reference.md` for application delivery and node-local persistent-storage patterns.
9. Review `docs/guides/nfs-storage-reference.md` for external shared-storage and NFS CSI integration.
10. Review `docs/guides/ingress-and-tls-reference.md` for ingress and TLS implementation.
11. Review `docs/guides/image-engineering-reference.md` for the DNS VM base-image contract.
12. Review `docs/guides/dns-lifecycle-control-reference.md` and `docs/runbooks/dns-lifecycle-control-runbook.md` for DNS architecture and lifecycle-control operations.
13. Review `docs/guides/backup-and-recovery-reference.md`.
14. Review `docs/guides/monitoring-and-alerting-reference.md`.
15. Review `docs/guides/management-gitops-reference.md`.
16. Review `docs/guides/stateful-application-reference.md` for the stateful application integration pattern.

This repository is deliberately conservative: examples are promoted only after
sanitization and explicit review.
