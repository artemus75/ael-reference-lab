# Example values for the management OpenTofu environment.
#
# Copy to terraform.tfvars for local use and replace all example values.
# Do not commit the local terraform.tfvars file.
#
# Secrets are intentionally not represented here:
# - proxmox_api_token should be supplied through TF_VAR_proxmox_api_token.

proxmox_endpoint     = "https://proxmox-management.example.invalid:8006/api2/json"
proxmox_api_token_id = "tofu@pve!ael-reference-lab-management"
talos_version        = "v1.13.8"

talos_nodes = {
  mgmt-cp-01 = {
    vmid         = 201
    role         = "controlplane"
    proxmox_node = "pve-mgmt-1"
    ip_address   = "192.0.2.201"
    cpu_cores    = 4
    memory_mb    = 8192
    disk_gb      = 64
    data_disk_gb = 128
  }
}
