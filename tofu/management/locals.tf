locals {
  vm_baseline = {
    cpu_type          = "host"
    sockets           = 1
    numa              = false
    memory_ballooning = false

    machine_type = "q35"
    bios         = "ovmf"
    secure_boot  = false
    tpm          = false

    datastore_id = "local-lvm"

    scsi_hardware  = "virtio-scsi-single"
    disk_interface = "scsi0"

    discard  = true
    iothread = true
    ssd      = true

    network_model   = "virtio"
    network_bridge  = "vmbr0"
    network_vlan_id = 60
    firewall        = true
  }

  proxmox_nodes = toset([
    "pve-mgmt-1",
  ])
}