output "dns_lifecycle_resources" {
  description = "Lifecycle metadata for DNS runtime resources managed by C3."

  value = {
    for name, node in var.dns_nodes :
    "proxmox_virtual_environment_vm.dns[\"${name}\"]" => {
      instance         = name
      lifecycle_domain = node.lifecycle_domain
      resource_role    = "vm"
    }
  }
}