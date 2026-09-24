# DNS C3 Public Runbook

This runbook describes reusable DNS/C3 operating procedures for the public
reference lab.

It intentionally excludes private validation evidence, raw command output, and
environment-specific incident history.

## Preconditions

- OpenTofu is installed.
- Ansible is installed.
- SSH access to the target hosts is available.
- Local OpenTofu variables are present and ignored by Git.
- Local Ansible inventory and group variables are present and ignored by Git.
- Required secrets are supplied through environment variables or Ansible Vault.

## Validate Inputs

Check that local copies exist before running automation:

```text
tofu/shared-infrastructure/environments/prod/terraform.tfvars
ansible/inventories/prod/hosts.yml
ansible/inventories/prod/group_vars/dns_servers/vars.yml
ansible/inventories/prod/group_vars/management_hosts/vars.yml
```

These files must remain untracked.

## OpenTofu Workflow

Run formatting and validation first:

```bash
tofu fmt -recursive
tofu validate
```

Review plans before applying:

```bash
tofu plan
```

Apply only after verifying that the planned changes match your intent:

```bash
tofu apply
```

## Ansible Workflow

Start with baseline checks:

```bash
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/playbooks/dns-baseline.yml
```

Configure Technitium DNS:

```bash
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/playbooks/technitium.yml
```

Inspect runtime state:

```bash
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/playbooks/technitium-inspect.yml
```

Run reconciliation where applicable:

```bash
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/playbooks/cluster-forwarder-reconcile.yml
```

Run the DNS health gate:

```bash
ansible-playbook -i ansible/inventories/prod/hosts.yml ansible/playbooks/dns-health-gate.yml
```

## Lifecycle Helper

The lifecycle helper is available at:

```text
scripts/lifecycle/c3-dns-lifecycle.sh
```

Use it only after reviewing the underlying OpenTofu and Ansible steps. The
script expects local variables and secrets to be available in your environment.

## Failure Handling

If a step fails:

1. Stop the lifecycle.
2. Preserve local logs outside the public repository if they contain private
   topology or secrets.
3. Check whether the failure is infrastructure, DNS configuration, credential,
   or network related.
4. Re-run only the smallest safe step after correcting the cause.

Do not commit raw failure logs, token values, or private environment output.
