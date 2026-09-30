locals {
  dns_proxmox_nodes = toset([
    for node in values(var.dns_nodes) : node.proxmox_node
  ])
}

resource "proxmox_virtual_environment_file" "debian_base_image" {
  for_each = local.dns_proxmox_nodes

  content_type = "import"
  datastore_id = "local-storage"
  node_name    = each.value

  source_file {
    path = "${path.module}/.build/artifacts/${var.debian_image_version}/${var.debian_image_file_name}"

    file_name = var.debian_image_file_name
    checksum  = var.debian_image_checksum
  }

  overwrite = false
}

resource "proxmox_virtual_environment_vm" "dns" {
  for_each = var.dns_nodes

  name      = each.key
  vm_id     = each.value.vmid
  node_name = each.value.proxmox_node

  description = each.key == "dns-01" ? "Shared Infrastructure DNS Server - C3 Scope Test" : "Shared Infrastructure DNS Server"

  machine = local.vm_baseline.machine_type
  bios    = local.vm_baseline.bios

  efi_disk {
    datastore_id      = local.vm_baseline.datastore_id
    type              = "4m"
    pre_enrolled_keys = false
  }

  agent {
    enabled = local.vm_baseline.qemu_guest_agent
  }

  serial_device {
    device = "socket"
  }

  stop_on_destroy = true

  cpu {
    cores   = each.value.cpu_cores
    sockets = local.vm_baseline.sockets
    type    = local.vm_baseline.cpu_type
  }

  memory {
    dedicated = each.value.memory_mb
    floating  = local.vm_baseline.memory_ballooning ? each.value.memory_mb : 0
  }

  scsi_hardware = local.vm_baseline.scsi_hardware

  disk {
    datastore_id = local.vm_baseline.datastore_id
    interface    = local.vm_baseline.disk_interface

    import_from = proxmox_virtual_environment_file.debian_base_image[each.value.proxmox_node].id

    size     = each.value.disk_gb
    discard  = "on"
    iothread = local.vm_baseline.iothread
    ssd      = local.vm_baseline.ssd
  }

  network_device {
    bridge      = local.vm_baseline.network_bridge
    model       = local.vm_baseline.network_model
    firewall    = local.vm_baseline.firewall
    mac_address = each.value.mac_address
  }

  initialization {
    datastore_id = local.vm_baseline.datastore_id

    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
      domain  = var.dns_search_domain
    }

    user_account {
      username = "debian"
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  operating_system {
    type = "l26"
  }
}
