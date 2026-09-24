variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint."
  type        = string
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

variable "ssh_public_key" {
  description = "SSH public key used for Cloud-Init access."
  type        = string
}

variable "gateway" {
  description = "IPv4 gateway used for DNS VM initialization."
  type        = string
}

variable "dns_servers" {
  description = "DNS servers used for DNS VM initialization."
  type        = list(string)
}

variable "dns_search_domain" {
  description = "DNS search domain used for DNS VM initialization."
  type        = string
}

variable "dns_nodes" {
  description = "DNS VMs providing shared infrastructure DNS services."

  type = map(object({
    vmid             = number
    proxmox_node     = string
    ip_address       = string
    mac_address      = string
    cpu_cores        = number
    memory_mb        = number
    disk_gb          = number
    lifecycle_domain = string
  }))
}

variable "debian_image_url" {
  description = "Pinned Debian GenericCloud image URL."
  type        = string
}

variable "debian_image_file_name" {
  description = "Local Proxmox import filename for the pinned Debian GenericCloud image."
  type        = string
}

variable "debian_image_checksum" {
  description = "SHA512 checksum of the pinned Debian GenericCloud image."
  type        = string
}
