packer {
  required_version = ">= 1.16.0"

  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "= 1.1.6"
    }
  }
}

locals {
  source_url = "https://cloud.debian.org/images/cloud/trixie/20260914-2601/debian-13-generic-amd64-20260914-2601.qcow2"

  source_checksum = "sha512:a733e7d49442a03e70d03e4eb5aaf3967f3efc69ef70952f9bb10fc1ee2c4876eb95956b5ad2d31350e5fada768feb651352535fb8cd1233f61998a5a7d2e93c"

  ssh_public_key = trimspace(file(".build/packer_ed25519.pub"))
}

source "qemu" "debian_13_proxmox" {
  iso_url      = local.source_url
  iso_checksum = local.source_checksum

  disk_image = true
  format     = "qcow2"

  accelerator  = "kvm"
  headless     = true
  machine_type = "q35"

  vm_name          = "debian-13-proxmox.qcow2"
  output_directory = "output/debian-13-proxmox"

  disk_size = "8G"
  memory    = 2048
  cpus      = 2

  cd_content = {
    "meta-data" = file("http/meta-data")
    "user-data" = templatefile("http/user-data.pkrtpl.hcl", {
      ssh_public_key = local.ssh_public_key
    })
  }

  cd_label             = "cidata"
  ssh_username         = "packer"
  ssh_private_key_file = ".build/packer_ed25519"
  ssh_timeout          = "10m"
}

build {
  name = "debian-13-proxmox"

  sources = [
    "source.qemu.debian_13_proxmox"
  ]

  provisioner "shell" {
    script = "scripts/bootstrap.sh"
  }

  provisioner "shell" {
    script            = "scripts/cleanup.sh"
    execute_command   = "sudo -S env {{ .Vars }} {{ .Path }}"
    expect_disconnect = true
  }
}
