#!/bin/bash
set -euo pipefail

# Clone repository
su - ubuntu -c "git clone https://github.com/folio-org/eureka-setup /home/ubuntu/eureka-setup"

# Install Go
wget -O /tmp/go.tar.gz https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

# Add Go and eureka-cli binary to PATH for ubuntu user
echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/ubuntu/.bashrc
echo 'export PATH=$PATH:/home/ubuntu/go/bin' >> /home/ubuntu/.bashrc

# Build and install eureka-cli
su - ubuntu -c "cd /home/ubuntu/eureka-setup/eureka-cli && /usr/local/go/bin/go install"

# Initialize .eureka directory and fix permissions
su - ubuntu -c "mkdir /home/ubuntu/.eureka"
su - ubuntu -c "/home/ubuntu/go/bin/eureka-cli help -o"

# Enable eureka-cli autocompletion
echo 'source <(eureka-cli completion bash)' >> /home/ubuntu/.bashrc

# Configure /etc/hosts
bash /home/ubuntu/eureka-setup/eureka-cli/misc/add-hosts.sh
