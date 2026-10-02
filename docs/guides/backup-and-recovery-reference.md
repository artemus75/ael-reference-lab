# Backup and Recovery Reference

This guide describes the Kubernetes backup and recovery pattern used by the
Architecture Engineering Lab public reference implementation.

The implementation uses Velero for Kubernetes resource protection, the Velero
node-agent and Kopia for file-system backup of persistent volume content, and
an S3-compatible object store as the external backup target.

The concrete reference uses Backblaze B2.

The public implementation is derived from a separately validated private
engineering environment. Private topology, credentials, raw runtime evidence,
backup histories, and environment-specific identities are intentionally
excluded.

## Architecture

Backup is a separate responsibility from primary storage and high
availability.

```text
Kubernetes resources ──────────────┐
                                   │
Persistent volume content ──┐      │
                            ↓      ↓
                         Velero
                            ↓
                    node-agent / Kopia
                            ↓
                    S3-compatible API
                            ↓
                      Backblaze B2
```

The reference architecture therefore distinguishes:

```text
RAID
  → storage-device resilience

shared storage
  → workload mobility and shared data access

backup
  → recoverable external copy

restore validation
  → evidence that recovery actually works
```

None of these mechanisms should be treated as interchangeable.

## Velero Reference

The Velero desired state is located under:

```text
kubernetes/backup/velero/
```

The reference configuration uses:

```text
Velero
Velero node-agent
Kopia file-system backup
S3-compatible object storage
```

Volume snapshots are disabled:

```yaml
snapshotsEnabled: false
```

The node-agent is enabled:

```yaml
deployNodeAgent: true
```

This reflects a file-system-backup architecture rather than a CSI snapshot
architecture.

## External Backup Target

The concrete reference implementation uses Backblaze B2 through its
S3-compatible API.

The public example configuration uses:

```text
Bucket:   example-kubernetes-backup
Region:   eu-central-003
Endpoint: https://s3.eu-central-003.backblazeb2.com
```

`example-kubernetes-backup` is a placeholder and must be replaced before use.

The architecture is not dependent on the bucket name used by the private
engineering environment.

## Credential Boundary

Velero references an existing Kubernetes Secret:

```text
velero-credentials
```

The credential itself is not stored in this repository.

The public desired state therefore defines the credential consumption contract
without publishing access keys.

A deployment must create the expected Secret independently before Velero can
access the object store.

Credential creation, storage, rotation, and delivery require a separate
secret-management mechanism.

## File-System Backup

The reference enables the Velero node-agent.

For persistent volume content the data path is:

```text
Persistent Volume
      ↓
workload mount
      ↓
Velero node-agent
      ↓
Kopia
      ↓
external object storage
```

This matters because backing up Kubernetes API resources alone does not prove
that persistent application data is protected.

Workloads that require file-system backup must opt their relevant volumes into
the Velero file-system-backup mechanism.

## Pod Security Boundary

The node-agent requires host-level access to Kubernetes storage paths.

For that reason the dedicated `velero` namespace has an explicit privileged
Pod Security policy:

```text
pod-security.kubernetes.io/enforce: privileged
pod-security.kubernetes.io/audit: privileged
pod-security.kubernetes.io/warn: privileged
```

This is a deliberate exception scoped to the backup subsystem.

It should not be interpreted as a recommendation to relax Pod Security
cluster-wide.

## Monitoring

The public reference includes:

```text
kubernetes/backup/velero/servicemonitor.yaml
```

The ServiceMonitor selects the Velero monitoring endpoint and integrates with
the monitoring stack through:

```yaml
release: monitoring
```

Monitoring backup software does not by itself prove recoverability.

Operational health, successful backup completion, and successful restore
validation are separate signals.

## AWS Plugin Compatibility Pin

The reference currently contains:

```text
velero/velero-plugin-for-aws:v1.14.3-rc.1
```

This version is intentionally preserved from the validated private
implementation.

It was used as a compatibility pin for the Backblaze B2 S3-compatible API
after the previously tested stable plugin version encountered a backup
finalization incompatibility.

The release-candidate version is not presented as a general recommendation or
as the desired permanent baseline for new deployments.

Before deploying this reference in a new environment, validate the current
stable Velero AWS plugin against the selected S3-compatible object store and
adopt a stable version when that validation succeeds.

Do not change a validated compatibility pin merely because a newer version
exists. Version changes should be treated as engineering changes and
revalidated.

## Restore-Test Harness

A reusable restore-test workload is provided under:

```text
kubernetes/backup/velero/restore-test/
```

It contains:

```text
namespace.yaml
pvc.yaml
deployment.yaml
test-data-configmap.yaml
```

The test workload is intentionally separate from production application
workloads.

Its purpose is to provide known persistent data that can be backed up,
destroyed, restored, and verified.

## Restore Validation Pattern

The intended validation flow is:

```text
Known seed data
      ↓
PVC
      ↓
workload writes persistent data
      ↓
Velero backup
      ↓
destructive removal
      ↓
Velero restore
      ↓
resources reconstructed
      ↓
persistent data verified
```

A backup reaching `Completed` is useful operational evidence, but it is not
equivalent to proof of recoverability.

The restore path must also be exercised.

## Restore-Test Storage Dependency

The public restore-test PVC references:

```text
storageClassName: nfs-csi
```

The test therefore assumes that an `nfs-csi` StorageClass exists.

This is an explicit dependency rather than a hidden fallback.

A deployment using another storage architecture should adapt the PVC while
preserving the restore-test contract.

## Known Test Data

The public ConfigMap contains the seed value:

```text
architecture-engineering-lab-restore-seed
```

This is test data, not private runtime evidence.

The restored workload can compare persistent content against known input to
make data recovery observable.

## Recovery Scope

The reference demonstrates a Kubernetes resource and file-system data
protection pattern.

It does not by itself provide:

- storage high availability;
- application-consistent database backup;
- database-native point-in-time recovery;
- multi-cluster disaster recovery;
- guaranteed RPO or RTO;
- protection against every object-store failure mode;
- proof that every application can be safely restored from file-system data.

Database workloads may require database-native backup and recovery mechanisms
in addition to Velero.

## Adaptation Checklist

Before using this reference in another environment:

1. replace `example-kubernetes-backup` with the intended object-store bucket;
2. validate the S3-compatible endpoint and region;
3. create `velero-credentials` without committing credentials to Git;
4. restrict object-store credentials to the required scope;
5. validate the current stable Velero AWS plugin against the selected object
   store;
6. confirm that node-agent privileges are acceptable for the target security
   model;
7. confirm that the intended workloads opt the correct volumes into
   file-system backup;
8. adapt the restore-test StorageClass if `nfs-csi` is unavailable;
9. validate backup completion;
10. perform a destructive restore test and verify the recovered data.

## Validation Boundary

The private Architecture Engineering Lab contains separate runtime evidence
for backup and destructive restore behavior.

That evidence is not copied into this repository.

A new deployment should independently establish at least:

```text
BackupStorageLocation available
        ↓
Velero control plane healthy
        ↓
node-agent available where required
        ↓
backup completes
        ↓
persistent volume backup completes
        ↓
source workload/data removed
        ↓
restore completes
        ↓
workload becomes functional
        ↓
known persistent data verified
```

Only the complete chain provides meaningful evidence of recoverability.

## Evidence Boundary

This guide describes a reusable backup and recovery pattern derived from a
validated private implementation.

The public repository does not contain private object-store credentials,
private bucket names, NAS identities, private network topology, backup
histories, incident logs, or raw restore evidence.

Deployments based on this reference require their own validation and do not
inherit the validation status of the private engineering environment.
