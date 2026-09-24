variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint."
  type        = string
}

variable "talos_nodes" {
  description = "Virtual Talos nodes provisioned on Proxmox."

  type = map(object({
    vmid         = number
    role         = string
    proxmox_node = string
    ip_address   = string
    cpu_cores    = number
    memory_mb    = number
    disk_gb      = number
  }))

  validation {
    condition = alltrue([
      for node in values(var.talos_nodes) :
      contains(["controlplane", "worker"], node.role)
    ])

    error_message = "Node role must be either 'controlplane' or 'worker'."
  }
}

variable "proxmox_api_token" {
  description = "Secret value of the Proxmox API token."
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_id" {
  description = "Proxmox VE API token identifier."
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version used for the cluster."
  type        = string
}
