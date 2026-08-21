#!/bin/bash
set -euo pipefail

# Clone repository
su - ubuntu -c "git clone https://github.com/folio-org/eureka-setup /home/ubuntu/eureka-setup"

# Install the Go version required by eureka-cli (toolchain directive takes precedence over the go directive;
# a two-part version such as "1.26" is normalized to "1.26.0" to match the release tarball name)
GO_VERSION="$(awk '/^toolchain go/ { sub(/^go/, "", $2); tc = $2 } /^go / { v = $2 } END { v = (tc != "" ? tc : v); if (v ~ /^[0-9]+\.[0-9]+$/) v = v ".0"; print v }' /home/ubuntu/eureka-setup/eureka-cli/go.mod)"
echo "Installing Go ${GO_VERSION} (from eureka-cli/go.mod)"
wget -O /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

# Add Go and eureka-cli binary to PATH for ubuntu user
echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/ubuntu/.bashrc
echo 'export PATH=$PATH:/home/ubuntu/go/bin' >> /home/ubuntu/.bashrc

# Build and install eureka-cli
su - ubuntu -c "cd /home/ubuntu/eureka-setup/eureka-cli && /usr/local/go/bin/go install"

# Initialize .eureka home directory with config files
su - ubuntu -c "/home/ubuntu/go/bin/eureka-cli help -o"

# Enable eureka-cli autocompletion
echo 'source <(eureka-cli completion bash)' >> /home/ubuntu/.bashrc

# Add aliases
echo "alias resync='sudo systemctl restart systemd-timesyncd.service'" >> /home/ubuntu/.bashrc

# Configure /etc/hosts
bash /home/ubuntu/eureka-setup/eureka-cli/misc/scripts/add-hosts.sh
