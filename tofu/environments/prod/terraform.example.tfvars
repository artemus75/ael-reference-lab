# Example values for the Talos production OpenTofu environment.
#
# Copy to terraform.tfvars for local use and replace all example values.
# Do not commit the local terraform.tfvars file.
#
# Secrets are intentionally not represented here:
# - proxmox_api_token should be supplied through TF_VAR_proxmox_api_token.

proxmox_endpoint     = "https://proxmox.example.invalid:8006/api2/json"
proxmox_api_token_id = "tofu@pve!ael-reference-lab"
talos_version        = "v1.13.8"

talos_nodes = {
  talos-cp-01 = {
    vmid         = 101
    role         = "controlplane"
    proxmox_node = "pve-a"
    ip_address   = "192.0.2.101"
    cpu_cores    = 4
    memory_mb    = 8192
    disk_gb      = 64
  }

  talos-cp-02 = {
    vmid         = 102
    role         = "controlplane"
    proxmox_node = "pve-b"
    ip_address   = "192.0.2.102"
    cpu_cores    = 4
    memory_mb    = 8192
    disk_gb      = 64
  }

  talos-cp-03 = {
    vmid         = 103
    role         = "controlplane"
    proxmox_node = "pve-c"
    ip_address   = "192.0.2.103"
    cpu_cores    = 4
    memory_mb    = 8192
    disk_gb      = 64
  }

  talos-wkr-01 = {
    vmid         = 111
    role         = "worker"
    proxmox_node = "pve-a"
    ip_address   = "192.0.2.111"
    cpu_cores    = 4
    memory_mb    = 8192
    disk_gb      = 64
  }

  talos-wkr-02 = {
    vmid         = 112
    role         = "worker"
    proxmox_node = "pve-b"
    ip_address   = "192.0.2.112"
    cpu_cores    = 4
    memory_mb    = 8192
    disk_gb      = 64
  }

  talos-wkr-03 = {
    vmid         = 113
    role         = "worker"
    proxmox_node = "pve-c"
    ip_address   = "192.0.2.113"
    cpu_cores    = 4
    memory_mb    = 8192
    disk_gb      = 64
  }
}
