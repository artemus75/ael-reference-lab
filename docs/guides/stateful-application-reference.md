# Stateful Application Reference

## Purpose

This reference demonstrates how a stateful, database-backed application
can consume multiple platform capabilities without treating all
persistent state as the same storage problem.

Nextcloud is used as the reference workload because it combines
application runtime state, shared user data, relational database state,
cache services, background processing, TLS publication, externalized
credentials, and backup integration.

The purpose is not to define a universal Nextcloud deployment. It is to
demonstrate a reusable stateful-application architecture contract.

## Architecture

The reference workload composes several platform services:

``` text
                         Client
                           |
                        Traefik
                           |
                    TLS + Ingress
                           |
                       Nextcloud
                     /     |      \
                    /      |       \
             local-app   nfs-csi   Redis
                  |         |      ephemeral
           runtime state  user data
                  |
             PostgreSQL
                  |
              local-db
                  |
          logical DB dump
                  |
              nfs-csi

Velero/Kopia backup intent
        |
application/runtime + user data + DB dump
```

The important architectural property is that persistent data is
classified by role before a storage mechanism is selected.

## Public Reference Structure

The implementation is located under:

``` text
kubernetes/apps/nextcloud/
├── certificate.yaml
├── ingress.yaml
├── namespace.yaml
├── postgresql-backup-pvc.yaml
└── values.yaml
```

The manifests contain the reusable application contract.
Environment-specific credentials are deliberately excluded.

## Application Publication

The application is published through the platform ingress and TLS
contracts already established elsewhere in the reference lab.

The public example uses:

``` text
Host:           nextcloud.k8s.example.com
Ingress class:  traefik
TLS secret:     nextcloud-tls
Issuer:         letsencrypt-production
```

The Helm-managed ingress is disabled.

Instead, the repository owns the Kubernetes `Ingress` and cert-manager
`Certificate` resources explicitly.

This keeps application publication aligned with the platform ingress
contract rather than hiding it inside application-specific chart
configuration.

## Secret Boundary

Credential values are not stored in the repository.

The workload references existing Kubernetes Secrets:

  Purpose                   Secret
  ------------------------- ------------------------
  Nextcloud administrator   `nextcloud-admin`
  PostgreSQL credentials    `nextcloud-postgresql`
  Redis authentication      `nextcloud-redis`
  TLS certificate           `nextcloud-tls`

The application values reference the required keys, but the
corresponding secret values remain external runtime dependencies.

A consumer of this reference must create the required Secrets through an
appropriate secret-management process before deploying the workload.

## Storage Classification

The workload deliberately separates persistent data by function.

  -----------------------------------------------------------------------------
  Data                  StorageClass      Access            Role
  --------------------- ----------------- ----------------- -------------------
  Nextcloud             `local-app`       RWO               application-local
  application/runtime                                       persistent state
  state                                                     

  PostgreSQL primary    `local-db`        RWO               live relational
  data                                                      database state

  Nextcloud user data   `nfs-csi`         RWX               shared file data

  PostgreSQL logical    `nfs-csi`         RWO               portable database
  backup staging                                            recovery artifact
  -----------------------------------------------------------------------------

This is an architectural classification rather than merely a Kubernetes
configuration detail.

Different data types have different availability, consistency,
portability, and recovery requirements.

## Application Runtime State

The main Nextcloud persistence uses:

``` text
StorageClass: local-app
Access mode:  ReadWriteOnce
Size:         8Gi
```

This volume contains application/runtime state that requires persistence
but does not require shared RWX semantics.

`local-app` is backed by the node-local storage reference published
separately in this repository.

Node-local persistence creates an explicit scheduling and failure-domain
dependency. Persistent data surviving on a node does not mean the
workload can transparently move to another node.

## Database State

PostgreSQL uses:

``` text
StorageClass: local-db
Size:         8Gi
```

The database volume contains live PostgreSQL state.

The reference deliberately distinguishes the live database volume from
the database recovery artifact.

The live PGDATA volume is not included in the Velero file-system-backup
intent expressed by these values.

## Shared User Data

Nextcloud user data uses:

``` text
StorageClass: nfs-csi
Access mode:  ReadWriteMany
Size:         20Gi
```

This separates shared user content from node-local application state.

The external NFS architecture is documented in:

``` text
docs/guides/nfs-storage-reference.md
```

Using external NFS changes the storage failure domain. It does not by
itself make the application highly available.

Application availability still depends on the availability and recovery
behavior of the NFS service, network path, CSI integration, database,
and application components.

## PostgreSQL Recovery Artifact

The reference creates a separate PVC:

``` text
nextcloud-postgresql-backup
```

with:

``` text
StorageClass: nfs-csi
Size:         1Gi
Mount:        /backup
```

The intended architecture is:

``` text
live PostgreSQL database
        |
        | logical database dump
        v
     /backup
        |
     nfs-csi
        |
portable recovery artifact
```

The recovery artifact is therefore separated from the physical
representation of live PostgreSQL PGDATA.

The public manifests provide the staging volume and mount. They do not
implement or schedule the database dump itself.

## Backup Intent

The workload expresses selective Velero file-system-backup intent
through pod annotations.

Nextcloud:

``` text
backup.velero.io/backup-volumes: nextcloud-main,nextcloud-data
```

PostgreSQL:

``` text
backup.velero.io/backup-volumes: db-backup
```

The resulting design intent is:

``` text
nextcloud-main
    -> application/runtime state

nextcloud-data
    -> shared user data

db-backup
    -> logical PostgreSQL recovery artifact
```

Live PostgreSQL PGDATA is intentionally outside this file-system-backup
selection.

This reflects an application-consistency boundary: moving database files
is not equivalent to producing a validated database recovery artifact.

The annotations express backup intent. They do not prove that a backup
or restore has succeeded in another environment.

## Redis

Redis is configured as a standalone service with authentication through
an existing Secret.

Persistence is disabled.

In this reference architecture Redis is treated as ephemeral
cache/session support rather than durable source-of-truth state.

This classification is intentional. Applications with different Redis
durability requirements must adapt the persistence contract.

## Background Processing

Nextcloud background processing is enabled through the chart's CronJob
mode with a five-minute schedule.

The CronJob runs with a restricted security context:

-   non-root UID/GID `33`,
-   privilege escalation disabled,
-   Linux capabilities dropped,
-   `RuntimeDefault` seccomp profile.

Background processing is therefore part of the application lifecycle
contract rather than an external manual operation.

## Security Context

The Nextcloud workload uses a restricted container security context
while retaining only the Linux capabilities required by the application
configuration.

The configuration includes:

``` text
allowPrivilegeEscalation: false
seccompProfile: RuntimeDefault
```

and explicitly controls Linux capabilities.

The PostgreSQL initialization container and Nextcloud CronJob also
receive explicit security constraints.

These settings are reference values, not a claim that the workload
satisfies every possible Kubernetes security baseline or
application-specific hardening requirement.

## Resource Contract

The public values define:

``` text
CPU request:     250m
Memory request:  512Mi
CPU limit:       1
Memory limit:    1Gi
```

These values make resource expectations explicit.

They are reference values derived from the source implementation and are
not universal sizing recommendations.

Consumers should validate sizing against their own workload
characteristics.

## Chart Boundary

`values.yaml` is the Helm values contract used by the reference
workload.

The source engineering record establishes that the workload was deployed
and reconciled using these values, but it does not preserve a
sufficiently explicit Nextcloud Helm chart version as part of this
public implementation contract.

For that reason this reference does not invent or imply a chart version.

Before reproducing the workload, consumers must select and pin a
compatible chart version and validate these values against that version.

Application version and Helm chart version are separate lifecycle
dimensions and must not be treated as interchangeable.

## Failure Domains

The workload spans multiple failure domains:

``` text
Nextcloud application
    |
    +-- local-app
    |     -> node-local storage dependency
    |
    +-- PostgreSQL
    |     -> local-db
    |     -> node-local database dependency
    |
    +-- user data
    |     -> nfs-csi
    |     -> external storage + network dependency
    |
    +-- Redis
          -> ephemeral runtime dependency
```

A healthy Kubernetes Pod alone is therefore insufficient evidence that
the complete application is healthy.

Stateful application validation must include the dependencies that hold
or transport application state.

## Recovery Model

The intended recovery model separates application resources, file data,
and database recovery:

``` text
1. Recreate application resources.
2. Recover application/runtime persistent data.
3. Recover shared user data.
4. Provision usable PostgreSQL storage.
5. Restore PostgreSQL from an application-consistent logical artifact.
6. Validate application-level health.
7. Resume normal background processing.
```

This is a recovery architecture, not evidence that those steps have been
successfully executed in every environment.

The public reference intentionally separates the recovery contract from
private lab execution evidence.

## Relationship to Other References

This workload composes several independently documented platform
contracts:

``` text
Node-local storage
    -> docs/guides/application-and-local-storage-reference.md

External NFS storage
    -> docs/guides/nfs-storage-reference.md

Ingress and TLS
    -> docs/guides/ingress-and-tls-reference.md

Backup and recovery
    -> docs/guides/backup-and-recovery-reference.md

Monitoring and alerting
    -> docs/guides/monitoring-and-alerting-reference.md
```

The value of the stateful workload is therefore not a new isolated
platform component. It demonstrates how previously established contracts
interact when consumed by a realistic application.

## Consumer Adaptation

Before using this reference in another environment:

1.  Select and pin a compatible Nextcloud Helm chart version.
2.  Replace the example application hostname.
3.  Provide the referenced Kubernetes Secrets through an appropriate
    secret-management process.
4.  Validate the `local-app`, `local-db`, and `nfs-csi` StorageClasses.
5.  Confirm that node-local storage failure semantics are acceptable.
6.  Validate the external NFS availability and recovery model.
7.  Validate the ingress and certificate issuer contract.
8.  Implement and test creation of the PostgreSQL logical recovery
    artifact.
9.  Validate backup completion for the selected application volumes.
10. Execute a destructive restore test before treating the workload as
    recoverable.
11. Validate application-level health after recovery.
12. Adapt resource sizing and security settings to the target
    environment.

## Validation

A reproduction should validate more than Kubernetes object creation.

At minimum, verify:

``` text
Application publication
    -> DNS resolves
    -> TLS certificate is valid
    -> ingress reaches the application

Application state
    -> main persistence is bound
    -> shared data persistence is bound
    -> application can read and write expected data

Database
    -> PostgreSQL persistence is bound
    -> application can use the database
    -> logical backup artifact can be created
    -> logical backup can be restored and validated

Backup
    -> selected volumes are actually backed up
    -> backup metadata completes successfully
    -> destructive restore succeeds

Recovery
    -> application-level health is restored
    -> user data is accessible
    -> database state is correct
    -> background processing resumes
```

Successful PVC binding or a Running Pod is not sufficient evidence of
application recoverability.

## Evidence Boundary

This public reference is derived from a privately engineered and
validated stateful workload.

The public repository intentionally contains the reusable architecture
contract and sanitized desired state, not the private environment's raw
evidence.

It does not publish or transfer:

-   private hostnames or topology,
-   runtime credentials,
-   private Kubernetes Secret values,
-   environment-specific PVC identities,
-   private node placement,
-   observed application-version evidence,
-   backup object or snapshot identifiers,
-   backup byte counts,
-   private database dump artifacts,
-   private recovery execution evidence.

Private validation does not automatically prove that a consumer's
deployment is healthy, highly available, backed up, or recoverable.

Those properties must be demonstrated again in the target environment.
