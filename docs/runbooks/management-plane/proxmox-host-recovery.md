# Runbook — Management Plane Proxmox Host Recovery

This runbook defines the public recovery procedure for restoring a single-node
Talos Management Plane after loss or replacement of its Proxmox host.

The procedure restores an existing Management Plane from a Proxmox VM backup.
It does not create a new Talos or Kubernetes cluster.

Private Architecture Engineering Lab recovery evidence, concrete host
identities, addresses, VM identifiers, MAC addresses, and environment-specific
storage names are intentionally excluded.

## Recovery Model

```text
Known-good Proxmox VM backup
        ↓
Backup transfer
        ↓
Integrity validation
        ↓
Replacement Proxmox host
        ↓
VM restore
        ↓
VM configuration validation
        ↓
Talos validation
        ↓
Kubernetes validation
        ↓
Flux validation
        ↓
End-to-end validation
```

Infrastructure restoration alone does not prove Management Plane recovery.
Recovery is complete only when the restored service passes all required
validation gates.

## Preconditions

Before starting recovery, verify that:

- a known-good Proxmox backup of the Management Plane VM exists;
- the backup contains all required VM disks;
- the replacement host has sufficient compute and storage capacity;
- the Management Plane network can be presented to the restored VM;
- the replacement host can access the backup artifact;
- administrative access to Talos, Kubernetes, and Flux is available;
- the original Management Plane VM is stopped or otherwise guaranteed not to
  become active.

## Critical Identity Safety Rule

Never allow the original and restored Management Plane VM instances to run
simultaneously.

A restored VM may retain the same logical machine identity, network identity,
Talos identity, and Kubernetes node identity as the source VM.

Before starting the restored instance, establish that the source instance
cannot become active.

---

## Phase 1 — Establish the Recovery Host

Install and configure Proxmox VE on the replacement host.

Verify the host and storage state:

```bash
hostnamectl
pveversion -v
ip -br addr
pvesm status
```

Do not continue until the replacement host is operational and the intended VM
storage is available.

### Gate 1 — Recovery Host Ready

Required state:

```text
Proxmox host reachable
Required bridge operational
Management network available
Target VM storage active
```

**Gate result: PASS required**

---

## Phase 2 — Validate Management Network Transport

The Proxmox bridge used by the Management Plane must provide the VLAN and
network transport required by the Management Plane VM.

Validate the effective bridge configuration:

```bash
ip -br addr
cat /etc/network/interfaces
```

A VLAN-aware bridge may, for example, require a configuration equivalent to:

```text
auto <bridge>
iface <bridge> inet static
        address <host-address>/<prefix>
        gateway <gateway>
        bridge-ports <physical-interface>
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids <management-vlan>
```

This is an example contract, not a topology that must be copied literally.

Apply network changes using the supported Proxmox/Debian network mechanism.

If network configuration must be changed remotely, ensure that a recovery or
out-of-band access path exists before applying the change.

### Gate 2 — Management Network Ready

Required state:

```text
Proxmox bridge UP
Required Management Plane VLAN or network available
Gateway reachable where required
VM storage remains available
```

**Gate result: PASS required**

---

## Phase 3 — Obtain the Backup

If a backup still needs to be created from an operational source host, use the
supported Proxmox backup mechanism.

Example pattern:

```bash
vzdump <vmid> \
  --storage <backup-storage> \
  --mode snapshot \
  --compress zstd
```

Verify that the backup operation completed successfully.

List available backup artifacts:

```bash
pvesm list <backup-storage> --content backup
```

A commonly used compressed Proxmox VM backup format is:

```text
vma.zst
```

### Gate 3 — Backup Available

Required state:

```text
Backup operation completed successfully
Expected backup artifact exists
Required VM disks are represented by the backup
```

**Gate result: PASS required**

Do not continue without a known-good backup artifact.

---

## Phase 4 — Transfer the Backup

If the backup is not already available on the recovery host, transfer it using
an appropriate protected transport mechanism.

One possible mechanism is `scp`:

```bash
scp <backup-file>.vma.zst \
  root@<replacement-host>:<destination-path>/
```

Verify that the artifact exists on the destination:

```bash
ls -lh <destination-path>/
```

If the destination is configured as Proxmox backup storage, also verify it
through Proxmox:

```bash
pvesm list <backup-storage> --content backup
```

Do not restore the VM yet.

---

## Phase 5 — Verify Backup Integrity

Calculate SHA-256 for the source artifact:

```bash
sha256sum <source-backup>
```

Calculate SHA-256 for the transferred artifact:

```bash
sha256sum <destination-backup>
```

Compare the complete hashes.

They must match exactly.

### Gate 4 — Backup Integrity

Required state:

```text
Source SHA-256 == Destination SHA-256
```

**Gate result: PASS required**

If the hashes differ:

```text
STOP
```

Do not restore the artifact.

Repeat the transfer or obtain another known-good backup.

---

## Phase 6 — Isolate the Source Management Plane

If the original Management Plane VM still exists and is running, shut it down
before the restored instance can become active.

Example:

```bash
qm shutdown <vmid>
```

Verify:

```bash
qm status <vmid>
```

Required state:

```text
status: stopped
```

Do not use forced termination as the normal recovery procedure.

If graceful shutdown fails, investigate before proceeding.

The safety objective is stronger than simply observing `stopped` once: the
original instance must not be able to return automatically while the restored
instance is active.

### Gate 5 — Source Isolated

Required state:

```text
Original Management Plane VM stopped
Original instance cannot become active concurrently
```

**Gate result: PASS required**

---

## Phase 7 — Restore the VM

Restore the backup to the intended target storage.

Example:

```bash
qmrestore \
  <backup-file> \
  <vmid> \
  --storage <target-storage>
```

Do not start the restored VM immediately after restore.

The next gate validates its configuration while the instance is still stopped.

---

## Phase 8 — Validate Restored VM Configuration

Verify that the restored VM is stopped:

```bash
qm status <vmid>
```

Expected:

```text
status: stopped
```

Inspect its configuration:

```bash
qm config <vmid>
```

Validate at minimum:

```text
VM identity
VM name
CPU model and core allocation
Memory allocation
Firmware
Machine type
Network bridge
VLAN or equivalent network attachment
Network interface identity where required
Required disks
Disk sizes
Target storage
Boot configuration
Automatic-start behavior
```

A changed VM generation identifier after restore may be expected.

Storage representation may differ when restoring between Proxmox storage
types. Validate functional equivalence rather than assuming identical storage
syntax.

The restored VM must still satisfy the infrastructure contract expected by the
Talos Management Plane.

### Gate 6 — Restored VM Contract Valid

Required state:

```text
VM stopped
Expected logical identity present
Compute configuration valid
Network configuration valid
All required disks present
Storage placement valid
Firmware and machine type valid
```

**Gate result: PASS required**

---

## Phase 9 — Start the Restored Management Plane

Start the restored VM:

```bash
qm start <vmid>
```

Verify:

```bash
qm status <vmid>
```

Required state:

```text
status: running
```

A working Proxmox console or serial terminal is not by itself a recovery
requirement. Service-level validation follows through Talos, Kubernetes, and
Flux.

### Gate 7 — VM Runtime Available

Required state:

```text
Restored Management Plane VM running
```

**Gate result: PASS required**

---

## Phase 10 — Validate Talos

From the administration workstation, verify Talos API availability:

```bash
talosctl -n <management-node-address> version
```

Then inspect cluster membership:

```bash
talosctl -n <management-node-address> get members
```

Validate that:

- the expected Management Plane member exists;
- the expected hostname is present;
- the machine is represented as a control-plane node;
- the expected Management Plane address is present;
- any API VIP required by the architecture is available.

### Gate 8 — Talos Operational

Required state:

```text
Talos API reachable
Expected Management Plane member present
Expected control-plane identity present
Expected node networking available
```

**Gate result: PASS required**

VM runtime alone does not prove that the Management Plane has recovered.

---

## Phase 11 — Validate Kubernetes

Select the intended Management Plane Kubernetes context using the local
administration workflow.

Inspect the node:

```bash
kubectl get nodes -o wide
```

Validate:

```text
Expected Management Plane node present
Role: control-plane
Status: Ready
Expected node address present
```

Additional cluster checks may be performed as appropriate for the environment.

### Gate 9 — Kubernetes Operational

Required state:

```text
Management Plane control-plane node Ready
Kubernetes API operational
```

**Gate result: PASS required**

Talos availability alone is not sufficient to declare recovery complete.

---

## Phase 12 — Validate Flux

Inspect Flux reconciliation:

```bash
flux get all -A
```

Validate at minimum:

```text
Expected GitRepository resources present
Expected Kustomization resources present
Required resources READY=True
```

The exact Git revision may differ from the revision present when the backup was
created.

That difference is not automatically a recovery failure. The relevant
condition is successful reconciliation against the intended current repository
revision.

### Gate 10 — GitOps Reconciliation Operational

Required state:

```text
Expected Flux source READY=True
Expected Flux system reconciliation READY=True
Expected Management Plane reconciliation READY=True
```

**Gate result: PASS required**

This gate verifies that recovery extends beyond the restored VM and Kubernetes
runtime into the intended declarative Management Plane state.

---

## Phase 13 — Perform Any Required Proxmox Host Identity Cutover

This phase applies when the replacement Proxmox host was initially configured
with a temporary hostname, address, or other temporary network identity.

Before reusing a production address or identity from the failed host, ensure
that the previous host is shut down and cannot return automatically.

Apply the intended final host configuration using the supported
Proxmox/Debian mechanism.

Reconnect using the final management path.

Verify:

```bash
hostnamectl
ip -br addr
qm status <vmid>
```

### Gate 11 — Host Cutover Complete

Required state:

```text
Expected Proxmox host identity active
Expected host network reachable
Restored Management Plane VM running
Previous conflicting host identity inactive
```

**Gate result: PASS required**

If no temporary host identity was used, document this phase as not applicable
rather than manufacturing a cutover operation.

---

## Phase 14 — Final End-to-End Validation

Repeat the Management Plane validation after all infrastructure, network, and
host-identity changes are complete.

### Talos

```bash
talosctl -n <management-node-address> get members
```

### Kubernetes

```bash
kubectl get nodes -o wide
```

### Flux

```bash
flux get all -A
```

Do not infer service recovery from a successful Proxmox restore.

All three service layers must remain operational after final cutover.

### Gate 12 — End-to-End Recovery

Required state:

```text
Talos operational
Kubernetes operational
Flux operational
Restored VM running on intended recovery host
Final host networking operational
```

**Gate result: PASS required**

---

## Recovery Success Contract

Recovery is complete only when every applicable required gate has passed.

| Layer | Required State |
| --- | --- |
| Recovery host | Replacement host operational |
| Proxmox | Hypervisor operational |
| Host networking | Required Management Plane transport available |
| VM storage | Required storage available |
| Backup | Known-good artifact available |
| Backup integrity | Transfer integrity verified |
| Source isolation | Original instance cannot run concurrently |
| Restored VM | Configuration contract validated |
| VM runtime | Restored VM running |
| Talos | API reachable |
| Talos membership | Expected Management Plane member present |
| Kubernetes | Control-plane node `Ready` |
| Flux source | `READY=True` |
| Flux reconciliation | Required Kustomizations `READY=True` |
| Final cutover | Intended host identity/network active where applicable |
| End-to-end validation | Talos, Kubernetes, and Flux remain operational |

Only when all applicable required gates pass may recovery be declared:

```text
MANAGEMENT PLANE RECOVERY: PASS
```

---

## Rollback

If recovery fails before final host cutover and the original host remains
intact:

1. stop the restored Management Plane VM;
2. verify that the restored instance is fully stopped;
3. ensure it cannot restart automatically;
4. restore the network conditions required by the original host;
5. start the original Management Plane VM;
6. validate Talos;
7. validate Kubernetes;
8. validate Flux.

Never start both Management Plane instances simultaneously.

If the original physical host is unavailable, rollback requires another
known-good backup or another viable recovery target.

A failed recovery must not be converted into an uncontrolled dual-instance
state in an attempt to restore service.

---

## Evidence to Capture

For every recovery execution, retain at minimum:

```text
Recovery date
Recovery scenario
Source host or source failure context
Target host
Proxmox version
Backup artifact identity
Backup timestamp
Backup SHA-256
Transfer integrity result
Target storage
Restored VM configuration validation
Source-isolation validation
Talos validation
Kubernetes validation
Flux validation
Host cutover result where applicable
Final end-to-end result
Observed failures
Observed deviations
Operator decisions
```

Do not overwrite evidence from previous recovery exercises.

Evidence should make it possible to distinguish:

```text
what was expected
what was executed
what was observed
what passed
what failed
what required operator intervention
```

---

## Known Limitations

This procedure does not establish:

- Management Plane high availability;
- automatic failover;
- automatic disaster recovery;
- recovery without a valid VM backup;
- durability of backups outside the Proxmox failure domain;
- recovery from a corrupted backup;
- recovery from corrupted Talos state;
- recovery from corrupted Kubernetes state;
- recovery from corrupted GitOps state;
- simultaneous loss of all required recovery artifacts;
- a defined RPO;
- a defined RTO.

Those properties require separate architecture decisions and validation.

A successful execution of this procedure demonstrates the tested recovery path.
It does not establish behavior for failure scenarios that were not exercised.

---

## Recovery Pattern

The reusable recovery pattern is:

```text
Backup
  ↓
Transfer
  ↓
Integrity Validation
  ↓
Source Isolation
  ↓
Restore
  ↓
Validate VM Contract
  ↓
Start
  ↓
Validate Talos
  ↓
Validate Kubernetes
  ↓
Validate Flux
  ↓
Host Cutover, if required
  ↓
End-to-End Validation
  ↓
PASS
```

The important boundary is:

```text
VM restored
    ≠
Management Plane recovered
```

The restored infrastructure is only a prerequisite.

The Management Plane is recovered when the complete required control path is
operational again.

---

## Evidence Boundary

This public runbook is derived from a recovery procedure validated in the
private Architecture Engineering Lab engineering system of record.

The public repository contains the reusable recovery contract and procedure,
not the private raw recovery evidence or environment-specific topology.

Concrete private values such as host addresses, VM identifiers, MAC addresses,
storage names, test timestamps, and captured command output are deliberately
not reproduced here.

Reproducing this procedure in another environment does not inherit the
validation result of the original experiment. A new execution must generate
its own evidence and satisfy its own recovery gates.
