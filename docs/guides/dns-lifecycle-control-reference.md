# DNS Lifecycle Control Reference Guide

This guide explains the public DNS lifecycle-control reference implementation.

The goal is to provide a reproducible shared-infrastructure DNS pattern without publishing private environment details, raw validation evidence, or internal incident history.

## Architecture Model

The reference implementation separates three concerns:

```text
DNS Data Plane
  -> independent DNS service endpoints

Technitium Management Plane
  -> cluster membership and configuration distribution

Lifecycle Plane
  -> controlled change across the DNS redundancy boundary
```

These planes are related but are not interchangeable availability mechanisms.

Technitium cluster membership does not replace direct DNS endpoint redundancy. Lifecycle Control does not make the DNS service redundant; it constrains how infrastructure changes cross an already redundant runtime architecture.

## What This Implements

The public reference contains:

- OpenTofu infrastructure for DNS VMs on Proxmox;
- an explicit versioned base-image consumption contract;
- example OpenTofu variables;
- sanitized Ansible inventory and group-variable templates;
- Technitium installation and desired-state automation;
- internal authoritative forward and reverse DNS examples;
- native iterative recursive resolution;
- Technitium cluster runtime discovery and validation;
- DNS baseline and L1-L6 health-gate playbooks;
- Lifecycle controller v0.5 lifecycle orchestration for the supported update scope.

## Repository Layout

```text
tofu/shared-infrastructure/
  OpenTofu configuration for DNS shared infrastructure

ansible/inventories/prod/
  Sanitized inventory and group-variable examples

ansible/roles/technitium/
  Technitium installation and DNS desired state

ansible/playbooks/
  DNS baseline, inspection, reconciliation, and health gates

scripts/lifecycle/
  lifecycle controller

docs/guides/image-engineering-reference.md
  Public base-image and artifact contract

docs/runbooks/dns-lifecycle-control-runbook.md
  Reproduction and operational workflow
```

## DNS Service Model

The example exposes two production resolver endpoints directly:

```text
dns-01 -> 192.0.2.30
dns-02 -> 192.0.2.31
```

There is no DNS virtual IP in this reference architecture.

Client resolver failover behavior depends on the client resolver implementation. Two configured endpoints provide service redundancy, but this reference does not claim latency-transparent failover.

## Authoritative DNS Model

Authoritative DNS and Technitium cluster roles solve different problems:

```text
Authoritative DNS role
  Primary / Secondary
        !=
Technitium cluster role
  Cluster Primary / Cluster Secondary
```

The reference implementation uses explicit internal authoritative namespaces such as:

```text
infra.example.com
k8s.example.com
```

Public authoritative DNS remains outside this internal DNS service.

Do not infer parent/child DNS delegation from the example unless you implement and validate that delegation separately.

## Recursive DNS Model

Technitium performs native iterative recursion for normal external resolution.

The reference does not configure a general upstream DNS forwarder as the default external-resolution path.

Conditional forwarding is a separate architecture concern and should be added only when a concrete consumer requirement requires it.

## Technitium Cluster Boundary

Technitium cluster functionality is treated as a management and configuration-distribution plane.

Normal Ansible reconciliation discovers and validates cluster runtime state. Cluster-shared writes are constrained to the current Cluster Primary where the role implements that writer guard.

Destructive cluster lifecycle operations remain explicit operator procedures.

The public reference intentionally does not automate ambiguous cluster recovery, promotion, force removal, or destructive membership repair.

## Image and VM Lifecycle

The DNS VMs consume an explicitly versioned, previously accepted Debian 13 / Proxmox QCOW2 artifact.

The public contract is:

```text
Pinned Debian source
  -> Packer build [public implementation: `packer/debian-13-proxmox/`]
  -> image acceptance
  -> versioned artifact + SHA256
  -> verified local artifact cache
  -> OpenTofu per-node import
  -> VM creation through import_from
  -> Ansible runtime reconciliation
```

See `docs/guides/image-engineering-reference.md` before provisioning the DNS VMs.

The public repository does not prescribe a private artifact source. Supply a validated artifact through your chosen distribution mechanism and place it in the documented local artifact cache.

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

ansible/inventories/prod/group_vars/all/vault.example.yml
  -> ansible/inventories/prod/group_vars/all/vault.yml
```

Keep these local files out of Git.

## Secrets

The Proxmox API token value is not represented in the examples. Supply it through the environment:

```bash
export TF_VAR_proxmox_api_token='REPLACE_WITH_LOCAL_SECRET'
```

Technitium and health-gate credentials should be supplied through Ansible Vault or another local secret mechanism. The repository provides `ansible/inventories/prod/group_vars/all/vault.example.yml` as the variable-name contract only; copy it to `vault.yml`, replace the placeholders, and encrypt the local file before use.

Do not commit Vault files, local inventory, OpenTofu state, plan files, or raw operational logs.

## Health-Gate Contract

Operational readiness is not inferred from infrastructure convergence.

The DNS health gate validates the service in layers:

| Layer | Contract |
|---|---|
| L1 | Proxmox VM runtime |
| L2 | QEMU Guest Agent |
| L3 | Technitium HTTP runtime |
| L4 | DNS UDP/TCP transport |
| L5 | authoritative DNS canary |
| L6 | recursive DNS service |

A successful OpenTofu apply is therefore not equivalent to a recovered or operationally ready DNS node.

## Lifecycle controller v0.5 Lifecycle Boundary

Lifecycle controller v0.5 provides a guarded rolling lifecycle around the production DNS pair.

Its safety controls include discovery planning, lifecycle metadata validation, a fleet pre-flight health gate, saved target plans, plan fingerprinting, explicit operator approval, Ansible reconciliation, per-instance health gates, peer-transition approval, final convergence assessment, and a final fleet health gate.

The current target-plan scope guard permits exactly one non-noop change for the resolved target when the action is:

```json
["update"]
```

A destructive replacement such as:

```json
["delete","create"]
```

is rejected.

Therefore Lifecycle controller v0.5 must not be described as a destructive VM replacement orchestrator.

## Reproduction Flow

Use this order:

```text
prepare and validate base image
  -> place artifact in local cache
  -> configure OpenTofu inputs
  -> provision DNS VMs
  -> apply DNS OS baseline
  -> reconcile Technitium
  -> perform explicit cluster lifecycle operations when required
  -> run DNS health gate
  -> use the lifecycle controller only within its documented lifecycle scope
```

See `docs/runbooks/dns-lifecycle-control-runbook.md` for the operational sequence.

## Public Evidence Boundary

This repository publishes the reproducible implementation and architecture contracts.

It does not publish the private Architecture Engineering Lab's raw failure evidence, internal recovery logs, environment-specific incident history, or complete engineering canon.

The reference implementation therefore shows how to reproduce and test the architecture without presenting private lab evidence as universal behavior.

## Public Safety Notes

The examples use `example.com` and documentation IP ranges. Replace them with values for your own environment.

Never publish:

- real token values;
- Vault files;
- generated secret-bearing machine configuration;
- OpenTofu state;
- local inventory;
- raw operational logs containing private topology;
- private DNS names.
