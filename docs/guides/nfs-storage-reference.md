# NFS Storage Reference

## Purpose

This reference describes the Kubernetes-side storage contract for consuming an external NFS service through the NFS CSI driver.

The architecture separates storage provided by the Kubernetes nodes from storage provided by an external system. The reference therefore focuses on the integration boundary between Kubernetes, the CSI driver, and an existing NFS export.

It does not provision or configure the NFS server itself.

## Architecture

The storage path is:

```text
External NFS service
        ↓
NFS export
        ↓
NFS CSI driver
        ↓
StorageClass: nfs-csi
        ↓
PersistentVolumeClaim
        ↓
dynamically provisioned PersistentVolume
        ↓
workload
```

The responsibilities are deliberately separated:

```text
NFS service
  owns the external storage and export

NFS CSI driver
  integrates the external storage with Kubernetes

StorageClass
  defines the Kubernetes provisioning contract

PersistentVolumeClaim
  requests storage through that contract

workload
  consumes the resulting persistent volume
```

## Public Reference Structure

The implementation is stored under:

```text
kubernetes/storage/nfs/
├── storageclass.yaml
├── test-pvc.yaml
└── test-deployment.yaml
```

`storageclass.yaml` defines the external NFS storage contract.

`test-pvc.yaml` requests a small `ReadWriteMany` volume through that StorageClass.

`test-deployment.yaml` mounts the claim into a validation workload.

## External Storage Boundary

The reference StorageClass uses:

```yaml
provisioner: nfs.csi.k8s.io
```

This declares a dependency on the NFS CSI driver.

The manifests in this directory do not install that driver. A cluster using this reference must already provide a compatible NFS CSI driver.

Likewise, this reference does not create an NFS server or export. The configured server and share must already exist and be reachable from the Kubernetes nodes.

The public example uses documentation-safe values:

```yaml
parameters:
  server: 192.0.2.171
  share: /srv/kubernetes-nfs
```

These values are placeholders and must be replaced for a real environment.

## StorageClass Contract

The public StorageClass is named:

```text
nfs-csi
```

Workloads can request storage through that stable Kubernetes-facing name without embedding the NFS server address or export path directly in their manifests.

This creates a useful abstraction boundary:

```text
workload
   ↓
storageClassName: nfs-csi
   ↓
StorageClass
   ↓
external storage implementation
```

The workload depends on the storage contract rather than directly on the external storage endpoint.

## Dynamic Provisioning

The StorageClass uses:

```yaml
volumeBindingMode: Immediate
```

A matching PersistentVolume can therefore be provisioned when the claim is created rather than waiting for workload scheduling.

The reference also enables:

```yaml
allowVolumeExpansion: true
```

Whether expansion succeeds in a particular environment still depends on the capabilities and behavior of the CSI driver and backing storage.

## Reclaim Semantics

The StorageClass declares:

```yaml
reclaimPolicy: Retain
```

This is an intentional data-protection boundary.

Deleting a Kubernetes claim must not be treated as equivalent to intentionally deleting the underlying data.

`Retain` reduces the risk that application lifecycle operations automatically become destructive storage lifecycle operations.

It also means that retained storage can require explicit operational cleanup or recovery handling after the Kubernetes object that originally referenced it has been removed.

## NFS Protocol

The reference explicitly requests:

```yaml
mountOptions:
  - nfsvers=4.1
```

This makes the expected NFS protocol version part of the declared storage contract rather than relying entirely on client-side defaults.

A target environment must provide an NFS service compatible with that contract.

## Shared Storage Validation

The validation claim requests:

```yaml
accessModes:
  - ReadWriteMany
```

and:

```yaml
storageClassName: nfs-csi
```

The claim therefore exercises the intended shared-storage path rather than the node-local storage path used elsewhere in the reference lab.

The validation workload mounts the claim at:

```text
/data
```

This provides a simple workload-level consumer for checking that the complete provisioning and mount path functions.

## Backup Integration

The validation Deployment includes:

```yaml
backup.velero.io/backup-volumes: data
```

This connects the storage consumer to the backup model used elsewhere in the reference lab.

The annotation expresses backup intent for the mounted volume. It does not by itself prove that a backup or restore is successful.

Backup and restore behavior must be validated separately using the backup architecture and procedures described in:

```text
docs/guides/backup-and-recovery-reference.md
```

## Storage Failure Domains

External NFS storage and node-local storage have different failure characteristics.

With node-local storage, application data can be tied directly to the availability of a particular Kubernetes node.

With external NFS storage, the persistent data is hosted outside that node-local storage boundary:

```text
Kubernetes node
      ↓
network
      ↓
external NFS service
      ↓
persistent data
```

A Kubernetes node failure therefore does not necessarily imply loss of the external persistent data.

However, this does not make the storage architecture automatically highly available.

The external NFS service, its network path, and its underlying storage remain dependencies of workloads using the StorageClass.

## Failure Versus Recovery

Storage availability and workload recovery are separate concerns.

A temporary loss of the NFS service can make an existing workload unable to access its mounted data even when Kubernetes itself remains healthy.

Recovery of the external service also does not guarantee that every existing workload mount immediately returns to a usable state.

The recovery contract must therefore be validated at the workload level rather than inferred solely from NFS server availability or Kubernetes control-plane health.

This public reference describes that architectural boundary. It does not claim a universal recovery behavior for NFS clients, CSI implementations, or applications.

## Relationship to Local Storage

The reference lab also publishes node-local storage classes under:

```text
kubernetes/storage/openebs/
```

The two storage models serve different architectural purposes.

A simplified distinction is:

```text
Node-local storage
  data placement is coupled to a Kubernetes node

External NFS storage
  data placement is outside the Kubernetes node
```

Neither model is universally preferable.

The appropriate choice depends on workload access mode, performance requirements, failure-domain design, data protection, and recovery requirements.

## Consumer Adaptation

Before using this reference in another environment:

1. Provide a compatible NFS service and export.
2. Ensure Kubernetes nodes can reach the NFS service.
3. Install and validate the NFS CSI driver.
4. Replace the example NFS server address.
5. Replace the example export path.
6. Review `Retain` against the intended data lifecycle.
7. Review NFSv4.1 compatibility.
8. Apply the StorageClass.
9. Apply the validation PVC.
10. Apply the validation Deployment.
11. Validate provisioning and workload access.
12. Validate failure and recovery behavior independently for the target environment.

## Validation

The Kubernetes objects can be inspected with:

```bash
kubectl get storageclass nfs-csi
kubectl get pvc nfs-csi-test
kubectl get pv
kubectl get deployment nfs-csi-test
kubectl get pods -l app=nfs-csi-test
```

After the validation pod is running, the mounted filesystem can be inspected from the workload:

```bash
kubectl exec deploy/nfs-csi-test -- mount
kubectl exec deploy/nfs-csi-test -- df -h /data
```

A successful mount demonstrates that the workload can consume the provisioned storage at that point in time.

It does not by itself establish performance, high availability, backup correctness, or recovery guarantees.

## Evidence Boundary

The private engineering environment has exercised NFS storage as part of broader storage, backup, application, and resilience work.

Those execution results are not transferred into this public repository as universal claims.

The public repository contains the reusable Kubernetes storage contract and validation workload, not private infrastructure identities, raw execution evidence, or environment-specific recovery results.

A deployment based on this reference requires its own validation of provisioning, accessibility, backup behavior, failure handling, and recovery.
