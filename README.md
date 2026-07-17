# 🚀 Overview

This repository contains resources to provision a QEMU virtual machine, enabling you to run the
FOLIO Eureka Platform locally with all required tooling in an isolated environment. Platform
deployment is managed via
[eureka-cli](https://github.com/folio-org/eureka-setup/tree/master/eureka-cli), which is installed
automatically during provisioning.

## Why Run This in a VM?

The FOLIO Eureka Platform consists of many services (Kafka, Postgres, Vault, Keycloak, Kong, and
others). Running them in a dedicated VM provides:

- **Isolation** — services are fully contained; no packages or Docker networks pollute the host.
  Teardown is clean and complete.
- **Reproducibility** — the VM is provisioned from scratch on every creation, ensuring a consistent
  and documented starting state.
- **Resource control** — CPU and RAM are explicitly allocated so the platform doesn't compete
  unpredictably with host processes.
- **Network containment** — the platform's internal service mesh stays on the libvirt NAT bridge and
  is not exposed to the broader network by default.
- **Host compatibility** — tooling versions required by the platform (Go, Docker, Maven) are
  installed inside the VM and don't interfere with the host.
- **Snapshots** — the VM can be suspended or snapshotted at a known-good state (e.g. after a full
  deploy) and restored instantly.

## Table of Contents

- [Prerequisites](#️-prerequisites)
- [Setup Virtual Machine](#️-setup-virtual-machine)
- [Start the FOLIO Eureka Platform](#-start-the-folio-eureka-platform)
- [Updating eureka-cli](#-updating-eureka-cli)
- [Accessing the FOLIO UI from the Host](#-accessing-the-folio-ui-from-the-host)
- [Intercepting Modules from the Host](#-intercepting-modules-from-the-host)
- [Suspending and Shutting Down](#️-suspending-and-shutting-down)
- [Snapshots](#-snapshots)

# ⚙️ Prerequisites

> **Linux only.** This setup relies on QEMU/KVM and libvirt, which are Linux-specific. Windows and
> macOS are not supported.

**Install Virtualization & Management Tools**

```sh
sudo apt install -y \
  qemu-kvm libvirt-daemon-system libvirt-clients \
  bridge-utils virt-manager cloud-utils
```

**Add Your User to Required Groups**

```sh
sudo adduser $USER libvirt
sudo adduser $USER kvm
```

<sup>⚠️ Log out and log back in for group changes to take effect.</sup>  
<sup>ℹ️ Being in the `libvirt` and `kvm` groups allows you to manage VMs without elevated
privileges.</sup>

**Configure User Permissions for `libvirt` Images Folder**

```sh
sudo setfacl -m u:$USER:rwx /var/lib/libvirt/images
sudo setfacl -d -m u:$USER:rwx /var/lib/libvirt/images
```

<sup>ℹ️ It is recommended to work within the `/var/lib/libvirt/images` directory because libvirt
manages VM disk images here by default. This ensures proper permissions, seamless integration with
virtualization tools, and avoids issues with image discovery or access by QEMU/KVM and related
utilities.</sup>

# 🖥️ Setup Virtual Machine

**Clone This Repository into the Images Folder**

```sh
cd /var/lib/libvirt/images
git clone git@github.com:alb3rtino/eureka-vm.git
cd eureka-dev-vm
```

<sup>ℹ️ QEMU requires direct access to the disk images, so the repository must be cloned into the
images folder rather than symlinked from another location.</sup>

**Configure the Setup Script**

Adjust the defined variables to your liking. Make sure to set `SSH_PUBKEY_PATH` for accessing the VM
via SSH.

```sh
vi virt-install.conf
```

**Execute the Setup Script**

Executing the setup script will create and start the virtual machine. Provisioning begins
automatically on first boot.

```sh
./virt-install.sh
```

**Get the Assigned VM IP Address**

```sh
virsh domifaddr eureka-vm # (replace with VM name)
```

<sup>ℹ️ The IP address will be displayed once the VM has booted.</sup>

**Login Via SSH**

```sh
ssh ubuntu@192.168.122.116 # (replace with VM IP)
```

<sup>ℹ️ The VM is accessible before provisioning is complete. Run `cloud-init status --wait` after
login to wait for provisioning to finish, or follow progress with
`tail -f /var/log/cloud-init-output.log`. Run `cloud-init status --long` to check for errors after
completion. Once provisioning is done, log out and back in or run `source ~/.bashrc` to make `go`
and `eureka-cli` available in your session.</sup>

# 🚀 Start the FOLIO Eureka Platform

SSH into the VM and run:

```sh
eureka-cli deployApplication
```

✅ Upon completion, the FOLIO Eureka Platform will be running and accessible from your host machine.

**Configure Host Access**

Add the following entry to your host's `/etc/hosts`, replacing `192.168.122.116` with your VM's
actual IP address:

```
192.168.122.116 eureka postgres.eureka kafka.eureka vault.eureka keycloak.eureka kong.eureka
```

**Monitor System Components**

| Service                      | URL                         | Credentials                 |
| ---------------------------- | --------------------------- | --------------------------- |
| FOLIO UI (see section below) | http://localhost:3000       | `diku_admin` / `admin`      |
| Keycloak                     | http://keycloak.eureka:8080 | `admin` / `admin`           |
| Kong Admin GUI               | http://kong.eureka:8002     | —                           |
| Vault                        | http://vault.eureka:8200    | `admin` / `admin`           |
| Kafka UI                     | http://eureka:9080          | —                           |
| MinIO Console                | http://eureka:9001          | `minioadmin` / `minioadmin` |
| Dozzle (container logs)      | http://eureka:8888          | —                           |
| Kibana                       | http://eureka:15601         | —                           |

# 🔄 Updating eureka-cli

To update eureka-cli to the latest version, pull the latest changes and rebuild:

```sh
cd ~/eureka-setup/eureka-cli
git pull && go install
```

# 🖥️ Accessing the FOLIO UI from the Host

The FOLIO UI bundle is built with three URLs compiled in at image build time:

- **Keycloak** (`http://keycloak.eureka:8080`) — a resolvable hostname, so auth redirects to
  Keycloak work correctly from the host via the `/etc/hosts` entry above.
- **Kong/OKAPI** (`http://localhost:8000`) — resolves to the host machine, not the VM. All API calls
  after login fail.
- **Redirect URI** (`http://localhost:3000`) — after login, Keycloak redirects back to
  `localhost:3000`. On the host this resolves to the host machine, not the VM.

As a result, the UI loads and redirects to Keycloak correctly, but the post-login redirect and all
subsequent API calls fail. The options below work around this.

**Option 1 — SSH tunnel (simplest):**

```sh
ssh -L 3000:localhost:3000 -L 8000:localhost:8000 ubuntu@eureka
```

Then open `http://localhost:3000` in your browser. Keep the SSH session open while using the UI.

**Option 2 — SSH config (persistent):**

Add to `~/.ssh/config`:

```
Host eureka
    HostName eureka
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    LocalForward 3000 localhost:3000
    LocalForward 8000 localhost:8000
```

Then `ssh eureka` is enough to establish the tunnel.

**Option 3 — Rebuild the UI image:**

Rebuild `platform-complete` with VM hostnames instead of `localhost` for both Kong and the redirect
URI:

```sh
eureka-cli deployUi -b --platformCompleteURL http://eureka:3000
```

After rebuilding, the UI is accessible directly at `http://eureka:3000` from the host without a
tunnel. All hostnames must be resolvable on the host (see the `/etc/hosts` entry above).

# 🔀 Intercepting Modules from the Host

`interceptModule` is a development workflow feature for debugging FOLIO modules locally without
rebuilding Docker images. It redirects Kong gateway traffic away from a deployed module container
to a locally running instance (e.g. in IntelliJ), so you can set breakpoints and debug live
traffic.

**How it works:**

- In **intercept mode**, it undeploys the existing module and its sidecar, deploys a custom sidecar
  configured to forward traffic to your local instance, and updates Kong's module discovery
  accordingly:
  ```
  Kong → Custom Sidecar → Local IntelliJ Instance
  ```

- In **restore mode** (`--restore`), it undeploys the custom sidecar, redeploys the original module
  and sidecar from the registry, and restores Kong routing to default.

**VM setup:**

Since eureka-cli runs inside the VM while the module runs on the host, `host.docker.internal` cannot
be used as the gateway — inside the VM it resolves to the VM's own Docker bridge, not the physical
host. Instead, use the host's libvirt bridge IP (`192.168.122.1`) for `-m`. The `-s` (sidecar)
parameter takes the Docker host gateway IP (e.g. `172.17.0.1`), since the custom sidecar is deployed
as a Docker container inside the VM. The sidecar port can be chosen freely.

```sh
eureka-cli interceptModule -n mod-orders \
  -m http://192.168.122.1:8081 \
  -s http://172.17.0.1:37002
```

**Host firewall** — allow incoming connections from the VM network on the module port:

```sh
sudo ufw allow from 192.168.122.0/24 to any port 8081
```

**Bind address** — the module in IntelliJ must bind to `192.168.122.1` (the libvirt bridge
interface) rather than `127.0.0.1`, so it accepts connections from the VM.

**Restore:**

```sh
eureka-cli interceptModule -n mod-orders -r
```

# ⏸️ Suspending and Shutting Down

**Suspend:**

```sh
virsh suspend eureka-vm
virsh resume eureka-vm
```

Suspending freezes the VM in memory. Note that the VM clock drifts on resume, which can cause Kafka
consumer group timeouts, Vault lease expirations, and JWT validation failures. libvirt triggers a time
sync automatically on resume, but it does not always work. To force a datetime sync manually:

```sh
sudo systemctl restart systemd-timesyncd
```

Alternatively, use the `resync` alias (available after provisioning).

**Shut down:**

```sh
virsh shutdown eureka-vm   # from the host
# or
sudo shutdown -h now       # from inside the VM
```

This sends a clean shutdown signal, allowing systemd to stop all services gracefully (Postgres
flushes WAL, Kafka closes log segments, etc.). All containers are configured with
`--restart unless-stopped` and will come back up automatically on the next boot without manual
intervention.

**Destroy the VM:**

```sh
./virt-delete.sh
```

Completely removes the VM and its disk image.

# 📸 Snapshots

Snapshots capture the full VM state at a point in time and can be restored instantly. A good time to
snapshot is after a successful `eureka-cli deployApplication`, so you can return to a known-good
state without redeploying from scratch.

**Create a snapshot:**

```sh
virsh snapshot-create-as eureka-vm --name "snapshot-name" --description "description" --atomic
```

`--atomic` ensures the snapshot is only saved if the operation fully succeeds.

**List snapshots:**

```sh
virsh snapshot-list eureka-vm
```

**Restore a snapshot:**

```sh
virsh snapshot-revert eureka-vm "snapshot-name"
```

**Delete a snapshot:**

```sh
virsh snapshot-delete eureka-vm "snapshot-name"
```
