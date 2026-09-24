data "talos_image_factory_extensions_versions" "required" {
  talos_version = var.talos_version

  filters = {
    names = [
      "qemu-guest-agent",
    ]
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.required.extensions_info[*].name
      }
    }
  })
}

data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "metal"
  architecture  = "amd64"
}

resource "proxmox_download_file" "talos_image" {
  for_each = local.proxmox_nodes

  node_name    = each.value
  datastore_id = "local-storage"
  content_type = "iso"

  url = data.talos_image_factory_urls.this.urls.disk_image

  file_name               = "talos-${var.talos_version}-amd64.raw.img"
  decompression_algorithm = "zst"

  overwrite           = false
  overwrite_unmanaged = false
  verify              = true
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = var.talos_nodes

  vm_id     = each.value.vmid
  name      = each.key
  node_name = each.value.proxmox_node

  description = "Talos Linux ${each.value.role} node managed by OpenTofu"

  machine       = local.vm_baseline.machine_type
  bios          = local.vm_baseline.bios
  scsi_hardware = local.vm_baseline.scsi_hardware

  started         = false
  stop_on_destroy = true
  cpu {
    cores   = each.value.cpu_cores
    sockets = local.vm_baseline.sockets
    type    = local.vm_baseline.cpu_type
  }
  memory {
    dedicated = each.value.memory_mb
  }
  efi_disk {
    datastore_id = local.vm_baseline.datastore_id
    type         = "4m"
  }
  disk {
    datastore_id = local.vm_baseline.datastore_id

    file_id = proxmox_download_file.talos_image[
      each.value.proxmox_node
    ].id

    interface = local.vm_baseline.disk_interface

    size     = each.value.disk_gb
    iothread = local.vm_baseline.iothread
    discard  = local.vm_baseline.discard ? "on" : "ignore"
    ssd      = local.vm_baseline.ssd
  }
  network_device {
    model    = local.vm_baseline.network_model
    bridge   = local.vm_baseline.network_bridge
    vlan_id  = local.vm_baseline.network_vlan_id
    firewall = local.vm_baseline.firewall
  }
  operating_system {
    type = "l26"
  }
}
