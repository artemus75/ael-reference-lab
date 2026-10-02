# Ingress and TLS Reference

This guide describes the public ingress and TLS reference pattern used by the
Architecture Engineering Lab.

The implementation combines Traefik for HTTP/HTTPS application delivery with
cert-manager for certificate lifecycle management. The reference uses Cilium
to expose Traefik through a Kubernetes LoadBalancer service and uses ACME
DNS-01 for certificate issuance.

The public implementation is derived from a separately validated private
engineering environment. Private topology, runtime evidence, credentials, and
environment-specific identities are intentionally excluded.

## Architecture

Application traffic and certificate lifecycle are separate control paths.

### Application Delivery

```text
Client
  ↓
DNS
  ↓
203.0.113.200
  ↓
Cilium LB-IPAM / L2 Announcement
  ↓
Traefik LoadBalancer Service
  ↓
web / websecure EntryPoint
  ↓
Ingress or IngressRoute
  ↓
Backend Service
```

Traefik owns the HTTP/HTTPS ingress boundary. Cilium owns the network path that
makes the Traefik LoadBalancer service reachable outside the cluster.

The reference LoadBalancer address is:

```text
203.0.113.200
```

This is documentation-safe example addressing and must be adapted to the
target environment.

### Certificate Lifecycle

```text
Certificate
  ↓
cert-manager
  ↓
ClusterIssuer
  ↓
DNS provider API credential
  ↓
DNS-01 challenge
  ↓
ACME validation
  ↓
Kubernetes TLS Secret
  ↓
Traefik
```

This separation is intentional. Routing configuration describes how traffic
reaches an application. Certificate resources describe the requested
certificate and the TLS Secret that should result from successful issuance.

## Traefik Reference

The Traefik Helm values are located at:

```text
kubernetes/ingress/traefik/values.yaml
```

The reference configuration establishes:

- Kubernetes Ingress support;
- Traefik CRD support;
- an explicit non-default `traefik` IngressClass;
- a LoadBalancer service;
- HTTP on port 80;
- HTTPS on port 443;
- permanent HTTP-to-HTTPS redirection;
- TLS on the `websecure` EntryPoint;
- Prometheus metrics and a ServiceMonitor;
- Gateway API disabled.

The reference implementation deliberately supports both standard Kubernetes
Ingress resources and Traefik-specific CRDs.

Standard application exposure can therefore use Kubernetes `Ingress`.
Traefik-specific platform capabilities can use resources such as
`IngressRoute` and `Middleware`.

Gateway API is not part of this reference configuration.

## LoadBalancer Dependency

Traefik does not itself provide the external network path.

The reference architecture expects the Kubernetes platform to provide
LoadBalancer reachability. In this repository that responsibility belongs to
Cilium LB-IPAM and Layer 2 Announcements.

The dependency is therefore:

```text
Cilium
  ↓
LoadBalancer reachability
  ↓
Traefik
  ↓
HTTP/HTTPS routing
```

A different environment may replace the Cilium-specific implementation while
preserving the same responsibility boundary.

## cert-manager Reference

The cert-manager Helm values are located at:

```text
kubernetes/tls/cert-manager/values.yaml
```

The reference configuration enables cert-manager CRDs and retains them across
Helm uninstall.

The controller, webhook, CA injector, and startup API check use explicit
security contexts including non-root execution, RuntimeDefault seccomp, no
privilege escalation, dropped capabilities, and read-only root filesystems
where configured.

Prometheus integration and a ServiceMonitor are enabled.

## ACME and DNS-01

The architecture pattern is:

```text
ACME
+
DNS-01
```

The concrete public reference implementation is:

```text
Let's Encrypt
+
Cloudflare DNS-01
```

Cloudflare is therefore an implementation choice in this reference, not a
requirement of the general ingress and certificate architecture.

Two ClusterIssuers are defined:

```text
letsencrypt-staging
letsencrypt-production
```

The staging issuer uses the Let's Encrypt staging directory. The production
issuer uses the Let's Encrypt production directory.

Keeping both issuers makes it possible to validate the certificate workflow
against the staging service before consuming production issuance capacity.

## DNS Provider Credential

Both ClusterIssuers reference:

```text
Secret: cloudflare-api-token
Key:    api-token
```

The Secret value is deliberately absent from the repository.

The reference manifests define only the contract by which cert-manager locates
the credential.

Before applying either ClusterIssuer, the corresponding Secret must exist in
the namespace in which cert-manager expects the referenced solver credential.

Do not commit the API token to Git.

For a real environment, the DNS provider credential should be restricted to
the permissions and DNS zones required for ACME DNS-01 operation.

## Explicit Certificate Resources

The reference pattern uses explicit cert-manager `Certificate` resources
rather than coupling certificate requests to Ingress annotations.

The responsibility split is:

```text
Ingress / IngressRoute
        ↓
routing intent

Certificate
        ↓
certificate intent

TLS Secret
        ↓
runtime TLS material
```

This keeps routing and certificate lifecycle independently visible in desired
state.

## Traefik Dashboard Reference

The dashboard example is located under:

```text
kubernetes/ingress/traefik/dashboard/
```

It contains:

```text
certificate.yaml
ingressroute.yaml
middleware.yaml
```

The public dashboard hostname is:

```text
traefik.k8s.example.com
```

`example.com` is placeholder configuration and must be replaced before use.

The dashboard path is:

```text
Client
  ↓
HTTPS
  ↓
IngressRoute
  ↓
BasicAuth Middleware
  ↓
api@internal
```

The IngressRoute exposes only the dashboard/API paths required by the Traefik
internal dashboard service.

## Dashboard Authentication

The Middleware references:

```text
Secret: traefik-dashboard-auth
```

The Secret itself is not stored in the repository.

The reference therefore defines the authentication dependency without
publishing credentials or password hashes.

A deployment must create the expected Secret independently before enabling the
dashboard route.

## Dashboard TLS

The dashboard `Certificate` requests a certificate for:

```text
traefik.k8s.example.com
```

using:

```text
ClusterIssuer: letsencrypt-production
TLS Secret:    traefik-dashboard-tls
```

The resulting TLS Secret resides in the `traefik` namespace alongside the
IngressRoute that consumes it.

This reflects the namespace boundary of Kubernetes Secrets.

## Secret Boundary

The public desired state intentionally contains references to Secrets but no
secret values.

Required runtime secrets include:

```text
cert-manager/cloudflare-api-token
traefik/traefik-dashboard-auth
```

The repository defines how platform components consume these secrets. Secret
creation, storage, rotation, and delivery require a separate secret-management
mechanism.

## Dependencies

The complete reference assumes:

- a functioning Kubernetes cluster;
- Cilium or another implementation capable of exposing LoadBalancer services;
- DNS for the selected application names;
- Traefik installed from the supplied Helm values;
- cert-manager installed from the supplied Helm values;
- the required DNS-provider credential;
- the required dashboard authentication Secret if the dashboard is enabled.

The manifests do not create external DNS-provider credentials.

## Adaptation Checklist

Before using this reference in another environment:

1. replace `203.0.113.200` with an address from the environment's LoadBalancer
   architecture;
2. replace `traefik.k8s.example.com` with the intended dashboard hostname;
3. replace `admin@example.com` with an appropriate ACME account contact;
4. confirm the `traefik` IngressClass contract;
5. confirm LoadBalancer reachability from intended clients;
6. create the DNS-provider credential without committing it to Git;
7. restrict DNS-provider permissions to the required scope;
8. create the dashboard BasicAuth Secret if the dashboard will be exposed;
9. validate issuance with the staging ClusterIssuer before relying on the
   production issuer;
10. validate HTTP-to-HTTPS redirection, TLS, routing, and certificate renewal
    behavior in the target environment.

## Validation Boundary

The private Architecture Engineering Lab contains separate runtime validation
for the engineering environment.

That evidence is not copied into this repository.

A new deployment should independently validate at least:

```text
LoadBalancer reachable
        ↓
HTTP redirects to HTTPS
        ↓
Traefik routing functional
        ↓
ACME account ready
        ↓
DNS-01 challenge succeeds
        ↓
Certificate Ready
        ↓
TLS Secret created
        ↓
HTTPS endpoint valid
```

Dashboard validation should additionally confirm that unauthenticated access
is rejected and authenticated access reaches the intended Traefik dashboard
route.

## Evidence Boundary

This guide describes a reusable desired-state pattern derived from a validated
private implementation.

It does not publish the private environment's raw evidence, DNS zone,
credentials, local secret paths, user identities, or runtime history.

Deployments based on this reference require their own validation and do not
inherit the validation status of the private engineering environment.
