#!/bin/bash

# Stop on errors
set -e

# Load configuration
source ./virt-install.conf

# Define constants
VM_CLOUD_IMG="ubuntu-${UBUNTU_VERSION}-server-cloudimg-amd64.img"
VM_OS_VARIANT="ubuntu${UBUNTU_VERSION}"
VM_DISK_IMG="$VM_NAME.qcow2"

# Verify SSH public key exists
if [ ! -f "$SSH_PUBKEY_PATH" ]; then
  echo "Error: SSH public key not found at '$SSH_PUBKEY_PATH'. Set SSH_PUBKEY_PATH in virt-install.conf."
  exit 1
fi

# Create seed image for cloud-init
SSH_PUBKEY="$(cat "$SSH_PUBKEY_PATH")"
export SSH_PUBKEY
export VM_NAME
export GO_VERSION
PROVISION_SCRIPT_B64="$(envsubst '${GO_VERSION}' < cloud-init/provision.sh | base64 -w0)"
export PROVISION_SCRIPT_B64
cloud-localds cloud-init.iso <(envsubst < cloud-init/user-data.template) <(envsubst < cloud-init/meta-data.template)

# Check for Ubuntu cloud image, download if missing
if [ ! -f "$VM_CLOUD_IMG" ]; then
  echo "$VM_CLOUD_IMG not found, downloading..."
  wget https://cloud-images.ubuntu.com/releases/${UBUNTU_VERSION}/release/$VM_CLOUD_IMG
fi

# Create disk image from cloud ISO
qemu-img create -f qcow2 -o backing_file="$VM_CLOUD_IMG",backing_fmt=qcow2 "$VM_DISK_IMG" "$VM_DISK_SIZE"

virt-install \
  --name "$VM_NAME" \
  --memory "$VM_MEMORY" \
  --vcpus "$VM_CPUS" \
  --disk path=./"$VM_NAME".qcow2,format=qcow2 \
  --cdrom ./cloud-init.iso \
  --import \
  --network network=default \
  --os-variant "$VM_OS_VARIANT" \
  --graphics none \
  --noautoconsole \

