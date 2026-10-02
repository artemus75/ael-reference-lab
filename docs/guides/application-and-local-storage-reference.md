# Application and Local Storage Reference

This guide describes the public reference pattern for validating application
delivery and consuming node-local persistent storage in the Architecture
Engineering Lab reference implementation.

The implementation combines a small stateless validation workload with
OpenEBS LocalPV storage classes. It is intentionally narrower than the private
engineering environment and does not contain private runtime evidence,
environment-specific addressing, or application data.

## Reference Scope

The public implementation contains two related reference patterns:

- a `whoami` workload for validating Kubernetes application delivery through
  Service, Ingress, and TLS;
- OpenEBS LocalPV configuration for node-local persistent workloads.

These patterns can be used independently. The `whoami` workload itself is
stateless and does not consume the OpenEBS storage classes.

## Application Validation Path

The `whoami` example provides a small workload for validating the application
delivery path:

```text
Client
  ↓
DNS
  ↓
Traefik
  ↓
TLS Ingress
  ↓
ClusterIP Service
  ↓
whoami replicas
```

The reference deployment uses three replicas and a topology spread constraint
based on `kubernetes.io/hostname`.

The container runs as a non-root user, drops Linux capabilities, disables
privilege escalation, and uses the runtime-default seccomp profile.

Readiness and liveness probes use the workload's `/health` endpoint.

## Application Components

The public manifests are located under:

```text
kubernetes/apps/whoami/
```

They define:

```text
Namespace
    ↓
Deployment
    ↓
ClusterIP Service
    ↓
Ingress
    ↓
Certificate
```

The public hostname is:

```text
whoami.k8s.example.com
```

`example.com` is documentation-only placeholder configuration and must be
replaced for a real environment.

The Ingress expects an IngressClass named:

```text
traefik
```

The Certificate expects a cert-manager ClusterIssuer named:

```text
letsencrypt-production
```

These names represent dependencies of the reference implementation. They do
not install Traefik or cert-manager themselves.

## Local Persistent Storage Model

The local-storage reference uses OpenEBS LocalPV with a Talos-backed host
storage path.

The storage relationship is:

```text
Talos UserVolume
/var/mnt/local-db
        │
        ▼
OpenEBS LocalPV
        │
        ├── local-db
        │      ↓
        │   database-oriented PVCs
        │
        └── local-app
               ↓
            application/runtime PVCs
```

The public OpenEBS configuration is located under:

```text
kubernetes/storage/openebs/
```

## Logical Storage Classes

The reference implementation defines two StorageClasses:

| StorageClass | Current BasePath | Intended consumer |
| --- | --- | --- |
| `local-db` | `/var/mnt/local-db` | Database-oriented persistent data |
| `local-app` | `/var/mnt/local-db` | Application/runtime persistent data |

Both StorageClasses deliberately use the same physical host path in the
current reference implementation.

They therefore do not represent separate physical storage tiers.

The distinction is a logical consumer contract. It allows database-oriented
and application-oriented consumers to reference different StorageClasses even
when both currently use the same underlying Talos UserVolume.

This also creates an evolution boundary: either StorageClass can later be
mapped to a different storage implementation without requiring consumers to
share the same storage-class identity.

## Binding and Reclaim Semantics

Both local StorageClasses use:

```yaml
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

`WaitForFirstConsumer` defers volume binding until Kubernetes has scheduling
context for the consuming workload.

`Retain` makes deletion of a PersistentVolumeClaim insufficient by itself to
discard the underlying persistent volume.

These settings are part of the reference contract and should be reviewed
against the lifecycle requirements of each environment.

## OpenEBS Placement

The OpenEBS LocalPV node deployment is restricted with the example node label:

```yaml
storage.example.com/local-db: "true"
```

This is a documentation-safe placeholder convention.

Nodes intended to provide this local storage must be labelled consistently, or
the selector must be adapted to the environment.

The referenced host path must also exist on eligible nodes before workloads
depend on it.

In the Architecture Engineering Lab design, that path is backed by a Talos
UserVolume rather than being treated as an implicitly available filesystem
directory.

## Pod Security Boundary

The OpenEBS namespace uses privileged Pod Security enforcement because the
LocalPV provisioner requires host-level storage access.

Audit and warning levels remain set to `restricted`:

```text
enforce: privileged
audit:   restricted
warn:    restricted
```

This makes the elevated runtime requirement explicit instead of weakening Pod
Security controls globally.

## Dependencies

The complete reference pattern assumes the following capabilities already
exist where applicable:

- a Kubernetes cluster;
- a prepared local storage path on eligible nodes;
- OpenEBS LocalPV;
- the required node label for OpenEBS placement;
- Traefik with an IngressClass named `traefik` for the ingress example;
- cert-manager with a ClusterIssuer named `letsencrypt-production` for the TLS
  example;
- DNS for the chosen application hostname.

The manifests intentionally do not create these platform dependencies.

## Failure-Domain Constraint

OpenEBS LocalPV is node-local storage.

A volume backed by a node-local path does not become shared or replicated
storage merely because Kubernetes manages its PersistentVolume.

Workloads using these StorageClasses therefore remain coupled to the storage
failure domain of the node that owns their data.

The public reference does not claim storage high availability, transparent
cross-node failover, or replicated persistence.

Those properties require a different storage architecture.

## Validation Boundary

The private Architecture Engineering Lab has separate runtime and resilience
evidence for the engineering environment.

That evidence is not copied into this public repository.

The public manifests and this guide define a reusable reference
implementation. Deploying them in another environment requires independent
validation of that environment.

At minimum, validation should establish:

```text
workload scheduled
        ↓
readiness healthy
        ↓
Service reachable
        ↓
Ingress reachable
        ↓
TLS valid
```

For workloads consuming LocalPV storage, validation should additionally
establish:

```text
eligible storage node
        ↓
PVC created
        ↓
PV dynamically provisioned
        ↓
PVC Bound
        ↓
workload consumes expected StorageClass
        ↓
data survives workload restart
```

Node-loss behavior must be tested separately because local persistence is
intentionally tied to a node failure domain.

## Adaptation Checklist

Before using the examples outside the reference repository:

1. replace `whoami.k8s.example.com` with the intended DNS name;
2. confirm the Traefik IngressClass name;
3. confirm the cert-manager ClusterIssuer name;
4. confirm `/var/mnt/local-db` exists through an intentional node-storage
   contract;
5. replace or adopt `storage.example.com/local-db`;
6. confirm OpenEBS LocalPV is installed with the required node placement;
7. review `Retain` and `WaitForFirstConsumer` against workload requirements;
8. validate application delivery and persistent-storage behavior in the target
   environment.

## Evidence Boundary

This guide is derived from an implementation that has been validated in the
private Architecture Engineering Lab.

The public repository contains the reusable desired-state pattern, not the
private lab's raw validation evidence, topology, operational history, or
environment-specific identities.

A deployment based on this reference does not inherit the validation status of
the private engineering environment.
