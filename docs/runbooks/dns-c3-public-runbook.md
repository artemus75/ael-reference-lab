# DNS C3 Public Runbook

This runbook describes the reproducible DNS/C3 operating sequence for the public reference lab.

It intentionally excludes private validation evidence, raw command output, credentials, and environment-specific incident history.

## Preconditions

Before provisioning DNS infrastructure:

- OpenTofu, Ansible, `jq`, `flock`, and `sha256sum` are available where required;
- SSH access to the target hosts is available;
- local OpenTofu variables and Ansible inventory have been created from the examples and remain ignored by Git;
- required secrets are supplied through environment variables or Ansible Vault;
- a versioned Debian 13 / Proxmox base-image artifact has passed the acceptance contract in `docs/guides/image-engineering-reference.md`;
- the artifact SHA256 has been verified.

## Prepare the Base Image

The infrastructure configuration does not download a floating upstream cloud image.

Prepare a validated QCOW2 artifact and place it at:

```text
tofu/shared-infrastructure/.build/artifacts/<version>/<filename>
```

For the example inputs:

```text
tofu/shared-infrastructure/.build/artifacts/v0.1.0/debian-13-proxmox-v0.1.0.qcow2
```

Set the matching version, filename, and SHA256 in your local `terraform.tfvars`.

The local `.build/` artifact cache is ignored by Git.

## Prepare Local Inputs

Create local copies:

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

These files must remain untracked.

Supply the Proxmox token through the environment:

```bash
export TF_VAR_proxmox_api_token='REPLACE_WITH_LOCAL_SECRET'
```

## Provision DNS VM Infrastructure

From `tofu/shared-infrastructure/`, initialize and validate OpenTofu:

```bash
tofu init
tofu fmt -check -recursive
tofu validate
```

Review the complete plan with the local environment file:

```bash
tofu plan -var-file=environments/prod/terraform.tfvars
```

Apply only after verifying that the planned resources, target Proxmox nodes, image identity, and actions match your intent:

```bash
tofu apply -var-file=environments/prod/terraform.tfvars
```

The configuration imports one copy of the validated image artifact per physical Proxmox node used by the DNS VMs.

## Apply the DNS OS Baseline

From the repository root:

```bash
ansible-playbook ansible/playbooks/dns-baseline.yml --ask-vault-pass
```

The baseline owns mutable operating-system desired state. The base image owns bootstrap capabilities that must already exist for infrastructure lifecycle management.

## Reconcile Technitium

Run:

```bash
ansible-playbook ansible/playbooks/technitium.yml --ask-vault-pass
```

The role installs and reconciles the supported Technitium desired state.

Technitium cluster formation and destructive cluster lifecycle operations are intentionally not inferred or automatically executed by normal Ansible convergence.

If cluster initialization, promotion, force removal, membership repair, or rejoin is required, perform it as an explicit operator procedure and validate the resulting cluster state before continuing.

## Inspect Runtime State

Use the inspection playbook where diagnostic visibility is required:

```bash
ansible-playbook ansible/playbooks/technitium-inspect.yml --ask-vault-pass
```

Do not publish raw output if it contains private topology, credentials, tokens, or other environment-specific information.

## Run the DNS Health Gate

Operational readiness requires the health gate:

```bash
ansible-playbook ansible/playbooks/dns-health-gate.yml --ask-vault-pass
```

The gate validates:

```text
L1 -> Proxmox VM runtime
L2 -> QEMU Guest Agent
L3 -> Technitium HTTP runtime
L4 -> DNS UDP/TCP transport
L5 -> authoritative DNS canary
L6 -> recursive DNS service
```

Do not treat an OpenTofu apply or successful Ansible execution alone as proof that the DNS service is operationally ready.

## C3 v0.5 Lifecycle Controller

The lifecycle controller is:

```text
scripts/lifecycle/c3-dns-lifecycle.sh
```

Before using it, review the script and the architecture guide.

The controller expects local OpenTofu variables, required secrets, the SSH public key, Ansible configuration, and the DNS health gate to be usable from the repository.

Its normal safety flow is:

```text
DISCOVER
  -> classify change
  -> fleet PRE-FLIGHT health gate
  -> explicit rolling-lifecycle approval
  -> target saved plan
  -> scope validation
  -> exact-plan approval
  -> apply
  -> Technitium reconciliation
  -> instance health gate
  -> peer-transition approval
  -> next DNS node
  -> final convergence assessment
  -> final fleet health gate
```

C3 v0.5 currently permits only the supported single-resource `["update"]` target-plan scope.

It rejects destructive replacement actions such as `["delete","create"]`.

Do not use C3 v0.5 as a destructive replacement orchestrator.

## Recovery Boundary

A useful reconstruction sequence for a DNS node is:

```text
OpenTofu infrastructure reconstruction
  -> DNS OS baseline
  -> Technitium reconciliation
  -> explicit cluster membership repair/rejoin when required
  -> DNS health gate
```

This public sequence is a reproduction contract, not a claim that simultaneous loss of all DNS nodes or complete Technitium platform-state loss has been validated.

## Failure Handling

If a step fails:

1. Stop before crossing the next redundancy boundary.
2. Preserve diagnostic evidence outside the public repository if it contains private topology or secrets.
3. Determine whether the failure belongs to image/bootstrap, infrastructure, operating-system baseline, Technitium configuration, cluster management, credentials, network reachability, or DNS service health.
4. Correct the smallest responsible layer.
5. Re-run the relevant reconciliation and health gate before proceeding to the peer node.

Do not bypass a failed health gate merely because infrastructure reports convergence.

## Public Safety Boundary

Do not commit:

- local released-image binaries;
- token values or credentials;
- Ansible Vault files;
- OpenTofu state or saved plans;
- local inventory or environment-specific tfvars;
- private DNS names;
- raw failure logs containing environment details.

The public repository should contain the reproducible contract, not private operational evidence.
