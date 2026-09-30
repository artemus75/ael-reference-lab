# Image Engineering Reference

This guide defines the public base-image contract used by the shared-infrastructure OpenTofu reference implementation.

It describes the reproducible architecture boundary. It does not publish the private Architecture Engineering Lab acceptance evidence, release history, or internal artifact source.

## Why the Image Is Part of the Infrastructure Contract

A VM declaration can enable the QEMU Guest Agent, but that declaration alone does not install the guest capability inside the operating system.

For lifecycle operations that depend on guest-agent communication during provisioning, the capability must already be present when the VM enters infrastructure management.

The reference architecture therefore separates three responsibilities:

| Layer | Responsibility |
|---|---|
| Packer / image build | bootstrap capabilities required at first boot |
| OpenTofu | VM infrastructure lifecycle and explicit image consumption |
| Ansible | mutable operating-system and service desired state |

The QEMU Guest Agent intentionally appears in both the image contract and the Ansible baseline.

The image guarantees bootstrap availability. Ansible guarantees continued runtime desired state.

## Reference Lifecycle

```text
Pinned Debian 13 source
  -> Packer build
  -> versioned QCOW2 candidate
  -> image acceptance
  -> released artifact + SHA256
  -> verified local artifact cache
  -> OpenTofu
  -> one Proxmox import per physical node
  -> VM disk import_from
  -> Ansible runtime reconciliation
```

A floating upstream `latest` image is not the OpenTofu input in this model.

OpenTofu consumes an explicitly versioned, previously validated artifact.

## Base-Image Requirements

The reference image is a generic Debian 13 / Proxmox base image.

It must provide the bootstrap capabilities required by the VM lifecycle while remaining independent of the DNS workload.

It must not contain:

- Technitium DNS;
- DNS zones or service configuration;
- environment-specific static addressing;
- Lab credentials or API tokens;
- workload secrets.

The current reference lifecycle requires QEMU Guest Agent support to be installed and enabled in the image.

## Acceptance Contract

Before an image is promoted for OpenTofu consumption, validate at least:

| ID | Contract | Acceptance Meaning |
|---|---|---|
| IMG-A1 | Boot | A VM created from the candidate boots successfully on Proxmox. |
| IMG-A2 | Cloud-Init | Proxmox-supplied Cloud-Init initialization completes successfully. |
| IMG-A3 | Network / SSH | Expected network configuration is applied and the intended SSH path works. |
| IMG-A4 | QEMU Guest Agent | Proxmox can communicate with the running guest agent through the Proxmox API. |
| IMG-A5 | Clean Image | No build credentials, persistent SSH host identities, Cloud-Init instance state, or environment secrets remain in the artifact. |

IMG-A4 is an API-boundary test. Checking only that a service is running inside the guest does not prove that Proxmox can use the capability.

## Artifact Identity

Use an explicit artifact identity such as:

```text
Artifact: debian-13-proxmox
Version:  v0.1.0
File:     debian-13-proxmox-v0.1.0.qcow2
SHA256:   <verified-sha256>
```

A changed binary requires a new version and checksum. Do not silently replace a released artifact while keeping its identity.

The public reference repository intentionally does not prescribe a specific artifact hosting service. GitHub Releases, an internal artifact service, or another controlled distribution mechanism can satisfy the architecture if the artifact identity and integrity contract is preserved.

## Preparing the Local Artifact

Obtain the released and accepted QCOW2 artifact through your chosen distribution mechanism.

Verify its SHA256 before OpenTofu consumes it.

Place it under:

```text
tofu/shared-infrastructure/.build/artifacts/<version>/<filename>
```

For the example inputs:

```text
tofu/shared-infrastructure/.build/artifacts/v0.1.0/debian-13-proxmox-v0.1.0.qcow2
```

Set the corresponding values in your local `terraform.tfvars`:

```hcl
debian_image_version   = "v0.1.0"
debian_image_file_name = "debian-13-proxmox-v0.1.0.qcow2"
debian_image_checksum  = "<verified-sha256>"
```

The `.build/` artifact cache is local state and is excluded from Git.

## OpenTofu Consumption

The shared-infrastructure configuration derives the set of physical Proxmox nodes used by the DNS VMs and manages one imported copy of the released artifact per node.

Conceptually:

```text
validated QCOW2
      |
      +--> pve-a import
      |       -> DNS VM on pve-a
      |
      +--> pve-b import
              -> DNS VM on pve-b
```

VM disks use the imported artifact associated with their target Proxmox node through `import_from`.

This keeps artifact identity explicit while avoiding one redundant upload per VM.

## Replacement Boundary

For the validated provider model, `import_from` is used when a VM is created.

Changing the configured image identity does not automatically prove that existing VMs have been rebuilt from the new image.

Image upgrades and destructive replacement therefore require an explicit lifecycle decision and separate validation.

The public C3 controller must not be assumed to provide destructive replacement orchestration unless its documented scope explicitly supports that action.

## Reproduction Contract

A reader reproducing this architecture should be able to establish the following chain:

```text
known image source
  -> reproducible image build
  -> acceptance gates pass
  -> immutable version/checksum
  -> local integrity verification
  -> OpenTofu import
  -> VM creation
  -> guest-agent communication through Proxmox
  -> Ansible runtime reconciliation
  -> service health validation
```

The important property is not the artifact hosting product.

The important property is that infrastructure provisioning consumes a known, validated image whose bootstrap capabilities satisfy the lifecycle contract.
