variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint for the Management infrastructure."
  type        = string
}

variable "proxmox_api_token" {
  description = "Secret value of the Management Proxmox API token."
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_id" {
  description = "Proxmox VE API token identifier for the Management Plane."
  type        = string
}

variable "talos_nodes" {
  description = "Virtual Talos nodes provisioned on the Management Proxmox host."

  type = map(object({
    vmid         = number
    role         = string
    proxmox_node = string
    ip_address   = string
    cpu_cores    = number
    memory_mb    = number
    disk_gb      = number
    data_disk_gb = number
  }))

  validation {
    condition = alltrue([
      for node in values(var.talos_nodes) :
      contains(["controlplane", "worker"], node.role)
    ])

    error_message = "Node role must be either 'controlplane' or 'worker'."
  }
}

variable "talos_version" {
  description = "Talos Linux version used for the Management cluster."
  type        = string
}
