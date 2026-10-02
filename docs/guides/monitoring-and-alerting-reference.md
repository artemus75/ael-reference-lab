# Monitoring and Alerting Reference

This guide describes the monitoring and alerting architecture used by the
Architecture Engineering Lab public reference implementation.

The reference uses kube-prometheus-stack as the central metrics platform,
Prometheus for time-series collection and alert evaluation, Grafana for
visualization, and Alertmanager for alert routing.

The implementation is derived from a separately validated private engineering
environment. Private topology, runtime evidence, credentials, operational
outputs, and environment-specific identities are intentionally excluded.

## Architecture

The primary monitoring path is:

```text
Platform component
      ↓
metrics endpoint
      ↓
ServiceMonitor
      ↓
Prometheus Operator
      ↓
Prometheus
      ├──→ Grafana
      └──→ PrometheusRule
                ↓
           Alertmanager
```

These responsibilities should not be collapsed into a single concept.

```text
Metrics collection
      ↓
Time-series storage
      ↓
Visualization
      ↓
Alert evaluation
      ↓
Notification routing
```

A working dashboard does not prove that alerting works, and a firing alert
does not prove that a human notification is delivered.

## kube-prometheus-stack

The central monitoring configuration is located at:

```text
kubernetes/monitoring/kube-prometheus-stack/values.yaml
```

The reference enables:

- Prometheus;
- Grafana;
- Alertmanager;
- Prometheus Operator;
- kube-state-metrics;
- Prometheus node-exporter;
- default Prometheus rules;
- default Grafana dashboards.

The public repository intentionally contains configuration rather than private
runtime evidence.

## Kubernetes Monitoring Scope

The reference enables monitoring for:

```text
kube-apiserver
kubelet
kube-state-metrics
node-exporter
CoreDNS
```

It disables the kube-prometheus-stack integrations for:

```text
kube-controller-manager
kube-scheduler
etcd
kube-proxy
```

These settings are architecture-specific.

They reflect the component exposure and kube-proxy-free design of the reference
environment and should not be treated as universal kube-prometheus-stack
defaults.

A different Kubernetes distribution or network architecture may require a
different monitoring configuration.

## Prometheus Persistence

Prometheus uses persistent storage:

```text
StorageClass: nfs-csi
AccessMode:   ReadWriteOnce
Size:         20Gi
Retention:    14d
Replicas:     1
```

These values are reference sizing, not general sizing recommendations.

Retention should be selected based on ingestion volume, query requirements,
available storage, operational objectives, and cost.

Persistent Prometheus storage does not provide Prometheus high availability.

## Grafana Persistence

Grafana also uses persistent storage:

```text
StorageClass: nfs-csi
AccessMode:   ReadWriteOnce
Size:         2Gi
```

The Grafana administrator credential is referenced through the existing
Kubernetes Secret:

```text
grafana-admin
```

with the keys:

```text
admin-user
admin-password
```

The Secret values are not stored in this repository.

## Grafana Access

Grafana is exposed through the ingress and TLS architecture established by the
reference platform:

```text
Client
  ↓
DNS
  ↓
Traefik
  ↓
Grafana Ingress
  ↓
Grafana Service
```

The public reference hostname is:

```text
grafana.k8s.example.com
```

TLS is represented explicitly through:

```text
kubernetes/monitoring/grafana/certificate.yaml
```

The resulting TLS Secret is:

```text
grafana-tls
```

Certificate issuance depends on the cert-manager architecture documented in
the Ingress & TLS Reference.

## ServiceMonitor Integration

Platform components expose metrics through ServiceMonitor resources.

The reference uses the common selector label:

```yaml
release: monitoring
```

This pattern is used by platform components such as Traefik, cert-manager, and
Velero.

Additional ServiceMonitors may be introduced as platform capabilities are
added.

A ServiceMonitor proves monitoring intent. Runtime validation must still
confirm that Prometheus discovers and successfully scrapes the target.

## Hubble UI

The reference also exposes Hubble UI through Traefik.

The public hostname is:

```text
hubble.k8s.example.com
```

The access path is:

```text
Client
  ↓
DNS
  ↓
Traefik websecure
  ↓
BasicAuth Middleware
  ↓
Hubble UI
```

The BasicAuth Middleware references:

```text
hubble-ui-auth
```

The credential itself is not stored in Git.

TLS uses the Certificate resource and:

```text
hubble-ui-tls
```

as the runtime TLS Secret.

## Platform Alerts

Reusable platform alert rules are maintained in:

```text
kubernetes/monitoring/alerts/platform-alerts.yaml
```

The public reference contains alerts for cert-manager, Cilium, and Velero.

The cert-manager rules cover:

```text
certificate not Ready
certificate expiration warning
certificate expiration critical
```

The Cilium rule detects failing controllers.

The Velero rules cover:

```text
backup location unavailable
backup failed
backup partially failed
```

These rules are starting points for operational validation, not a complete
production alerting policy.

## Environment-Specific Alert Thresholds

Alert thresholds must have an explicit operational meaning.

The private engineering environment contains a Hubble Relay peer-count alert
whose threshold is derived from that environment's expected cluster size.

That rule is intentionally not included in the public reference.

Replacing the private peer count with an arbitrary example number would create
a configuration that appears reusable while encoding no valid operational
contract.

A deployment that requires peer-count alerting should derive its threshold
from its own expected topology.

This illustrates a broader rule:

```text
Alert rule
  + meaningful threshold
  + known operating context
  = actionable monitoring contract
```

Copying a threshold without its context does not preserve that contract.

## Alertmanager Boundary

Alertmanager is enabled in the reference configuration.

However, the public reference does not configure external notification
destinations such as:

```text
email
Slack
PagerDuty
generic webhooks
```

Therefore:

```text
PrometheusRule
      ↓
Alertmanager
```

does not by itself establish:

```text
Alertmanager
      ↓
human notification
```

Notification routing is a separate operational responsibility.

## Monitoring Is Not Complete Observability

This reference establishes a metrics and alerting baseline.

It does not include:

- centralized application logging;
- Loki;
- distributed tracing;
- application performance monitoring;
- SIEM integration;
- production SLO definitions;
- synthetic availability monitoring;
- complete notification routing.

These capabilities may be added independently without changing the core
metrics architecture.

## Dashboard Boundary

The kube-prometheus-stack default dashboards provide useful operational views.

Dashboards are visualization artifacts.

They do not establish:

```text
service-level objectives
recovery objectives
availability guarantees
alert quality
incident response readiness
```

Those require separate engineering decisions and validation.

## Storage Dependency

Both Prometheus and Grafana depend on:

```text
storageClassName: nfs-csi
```

A deployment without this StorageClass must adapt the persistence
configuration.

Changing the storage implementation does not require changing the monitoring
responsibility model.

## Secret Boundary

The public monitoring desired state references secrets such as:

```text
grafana-admin
hubble-ui-auth
```

Secret values remain outside Git.

A deployment must provide those credentials through an appropriate
secret-management mechanism.

## Adaptation Checklist

Before using this reference in another environment:

1. validate which Kubernetes control-plane metrics endpoints are actually
   available;
2. adapt Prometheus storage sizing and retention;
3. provide the required `nfs-csi` StorageClass or replace the storage
   configuration;
4. create the Grafana administrator Secret outside Git;
5. replace the example Grafana and Hubble hostnames;
6. validate cert-manager and Traefik dependencies;
7. validate every ServiceMonitor target in Prometheus;
8. review every alert expression against the deployed component versions;
9. derive topology-dependent thresholds from the actual environment;
10. configure and test notification routing if human alert delivery is
    required.

## Validation Boundary

A deployment should independently establish at least:

```text
metrics endpoint available
      ↓
ServiceMonitor selected
      ↓
Prometheus target discovered
      ↓
scrape successful
      ↓
time series available
      ↓
dashboard/query functional
      ↓
alert expression evaluated
      ↓
test condition produces expected alert
```

Where notification delivery is required, extend the chain:

```text
Alertmanager receives alert
      ↓
routing policy matches
      ↓
notification integration accepts message
      ↓
intended recipient receives notification
```

Each layer requires its own evidence.

## Evidence Boundary

This guide describes a reusable monitoring and alerting pattern derived from a
validated private implementation.

The public repository does not contain private runtime outputs, private
topology, credentials, historical alert events, or raw validation evidence.

Deployments based on this reference require their own validation and do not
inherit the validation status of the private engineering environment.
