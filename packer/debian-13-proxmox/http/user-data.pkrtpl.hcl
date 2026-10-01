#cloud-config

users:
  - name: packer
    gecos: Temporary Packer Build User
    groups:
      - sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - ${ssh_public_key}

ssh_pwauth: false

package_update: false
package_upgrade: false
