#!/bin/bash

source ./virt-install.conf

virsh destroy "$VM_NAME" 2>/dev/null
virsh undefine "$VM_NAME" --remove-all-storage
