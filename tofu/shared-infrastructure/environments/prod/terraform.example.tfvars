# Example values for the shared-infrastructure OpenTofu environment.
#
# Copy to terraform.tfvars for local use and replace all example values.
# Do not commit the local terraform.tfvars file.
#
# Secrets are intentionally not represented here:
# - proxmox_api_token should be supplied through TF_VAR_proxmox_api_token.
#
# The validated base-image artifact is supplied out of band and placed at:
# .build/artifacts/<version>/<filename>
# Verify its SHA256 before running OpenTofu.

proxmox_endpoint = "https://proxmox.example.com:8006/api2/json"

proxmox_api_token_id = "tofu@pve!shared-infrastructure"

gateway           = "192.0.2.1"
dns_servers       = ["192.0.2.1"]
dns_search_domain = "infra.example.com"

debian_image_version   = "v0.1.0"
debian_image_file_name = "debian-13-proxmox-v0.1.0.qcow2"
debian_image_checksum  = "REPLACE_WITH_RELEASE_ARTIFACT_SHA256"

dns_nodes = {
  dns-01 = {
    vmid             = 301
    proxmox_node     = "pve-a"
    ip_address       = "192.0.2.30"
    mac_address      = "02:00:00:00:00:30"
    cpu_cores        = 2
    memory_mb        = 2048
    disk_gb          = 16
    lifecycle_domain = "production"
  }

  dns-02 = {
    vmid             = 302
    proxmox_node     = "pve-b"
    ip_address       = "192.0.2.31"
    mac_address      = "02:00:00:00:00:31"
    cpu_cores        = 2
    memory_mb        = 2048
    disk_gb          = 16
    lifecycle_domain = "production"
  }

  dns-lab-01 = {
    vmid             = 303
    proxmox_node     = "pve-a"
    ip_address       = "192.0.2.32"
    mac_address      = "02:00:00:00:00:32"
    cpu_cores        = 2
    memory_mb        = 2048
    disk_gb          = 16
    lifecycle_domain = "lab"
  }

  dns-lab-02 = {
    vmid             = 304
    proxmox_node     = "pve-b"
    ip_address       = "192.0.2.33"
    mac_address      = "02:00:00:00:00:33"
    cpu_cores        = 2
    memory_mb        = 2048
    disk_gb          = 16
    lifecycle_domain = "lab"
  }
}
