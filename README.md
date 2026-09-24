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
| OpenTofu shared infrastructure | `tofu/shared-infrastructure/` | Example Proxmox-backed DNS/C3 infrastructure module. |
| DNS automation | `ansible/roles/technitium/` | Technitium DNS installation and authoritative zone automation. |
| DNS playbooks | `ansible/playbooks/` | Public playbooks for DNS baseline, inspection, reconciliation, and health gates. |
| Example inventory | `ansible/inventories/prod/` | Example inventory and variables using documentation-safe placeholder values. |
| Lifecycle helper | `scripts/lifecycle/c3-dns-lifecycle.sh` | DNS/C3 lifecycle orchestration helper. |
| Public guides | `docs/guides/` | Reproduction-oriented documentation. |
| Public runbooks | `docs/runbooks/` | Reusable operational procedures without private lab evidence. |

## Reference Topology

The example topology uses documentation-safe values:

- DNS cluster nodes: `dns-01`, `dns-02`
- DNS lab nodes: `dns-lab-01`, `dns-lab-02`
- Example domain: `example.invalid`
- Example infrastructure zone: `infra.example.invalid`
- Example Kubernetes zone: `k8s.example.invalid`
- Example address range: `192.0.2.0/24`
- Example service address range: `198.51.100.0/24`

Replace these values before using the examples in your own environment.

## Secret Handling

Do not commit local runtime values.

The examples intentionally exclude:

- Proxmox API token values
- Ansible Vault files
- local inventory files
- OpenTofu state and plan files
- generated Talos machine configuration
- kubeconfig and talosconfig files

Use the provided `*.example.*` files as templates and keep local copies ignored
by Git.

## Getting Started

1. Review `docs/guides/dns-c3-reference.md`.
2. Copy the example OpenTofu variables and replace placeholder values.
3. Copy the example Ansible inventory and group variables.
4. Provide secrets through environment variables or Ansible Vault.
5. Run the lifecycle steps incrementally and validate each step before moving on.

This repository is deliberately conservative: examples are promoted only after
sanitization and explicit review.
