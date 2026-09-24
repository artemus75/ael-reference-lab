# DNS C3 Reference Guide

This guide explains the public DNS/C3 reference implementation.

The goal is to provide a reproducible pattern for a small lab DNS control plane
without publishing private environment details.

## What This Implements

The current public batch contains:

- an OpenTofu module for DNS node infrastructure on Proxmox
- example OpenTofu variables
- an Ansible inventory template
- Technitium DNS installation and configuration automation
- DNS baseline and health-gate playbooks
- a lifecycle helper script for repeatable execution

## Repository Layout

```text
tofu/shared-infrastructure/
  OpenTofu configuration for DNS/C3 infrastructure examples

ansible/inventories/prod/
  Example inventory and group variables

ansible/roles/technitium/
  Technitium DNS role

ansible/playbooks/
  DNS baseline, inspection, reconciliation, and health-gate playbooks

scripts/lifecycle/
  Lifecycle helper for ordered DNS/C3 operations
```

## Required Local Inputs

Create local files from the examples:

```text
tofu/shared-infrastructure/environments/prod/terraform.example.tfvars
  -> tofu/shared-infrastructure/environments/prod/terraform.tfvars

ansible/inventories/prod/hosts.example.yml
  -> ansible/inventories/prod/hosts.yml

ansible/inventories/prod/group_vars/dns_servers/vars.example.yml
  -> ansible/inventories/prod/group_vars/dns_servers/vars.yml

ansible/inventories/prod/group_vars/management_hosts/vars.example.yml
  -> ansible/inventories/prod/group_vars/management_hosts/vars.yml
```

Keep the local files out of Git.

## Secrets

The Proxmox API token value is not represented in any example file. Supply it
through the environment:

```bash
export TF_VAR_proxmox_api_token='REPLACE_WITH_LOCAL_SECRET'
```

Technitium and health-gate credentials should be supplied through Ansible Vault
or another local secret mechanism. Do not commit Vault files to this repository.

## Suggested Execution Flow

1. Adapt the OpenTofu example variables to your Proxmox environment.
2. Run OpenTofu formatting and validation.
3. Plan infrastructure changes.
4. Apply infrastructure changes only after reviewing the plan.
5. Adapt the Ansible example inventory and group variables.
6. Run DNS baseline checks.
7. Install and configure Technitium DNS.
8. Run inspection and reconciliation playbooks.
9. Run the DNS health gate.

The lifecycle helper script can be used to standardize these steps, but it
should not replace reviewing plans and playbook output.

## Public Safety Notes

The public examples use placeholder domains and documentation IP ranges. Replace
them with values for your own lab.

Never publish:

- real token values
- Vault files
- generated machine configuration
- OpenTofu state
- local inventory files
- raw operational logs
- private DNS names
