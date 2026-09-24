locals {
  vm_baseline = {
    cpu_type          = "host"
    sockets           = 1
    memory_ballooning = false

    machine_type = "q35"
    bios         = "ovmf"

    datastore_id = "local-lvm"

    scsi_hardware  = "virtio-scsi-single"
    disk_interface = "scsi0"

    discard  = true
    iothread = true
    ssd      = true

    network_model  = "virtio"
    network_bridge = "vmbr0"
    firewall       = true

    qemu_guest_agent = true
  }
}
