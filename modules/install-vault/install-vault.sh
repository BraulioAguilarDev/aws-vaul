#!/bin/bash

###########################################
#
#   Hashicorp Vault Setup on Amazon Ec23
#
###########################################
set -e

readonly VAULT_VERSION=${VAULT_VERSION}
readonly SYSTEMD_CONFIG_VAULT=/etc/systemd/system/vault.service
readonly VAULT_CONFIG_FILE=/etc/vault.d/vault.hcl

readonly VAULT_DATA=/vault-data

sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl unzip

# Download the vault binary
curl -L https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip -o vault.zip && \
  unzip vault.zip && \
  rm -f vault.zip && \
  chmod +x vault && \
  sudo mv vault /usr/bin/

# Create a user named vault to run as a service
sudo useradd --system --home /etc/vault.d --shell /bin/false vault

# Configure Vault as a System Service
cat <<EOF >$SYSTEMD_CONFIG_VAULT
  [Unit]
  Description=HashiCorp Vault Service
  Documentation=https://www.vaultproject.io/docs/
  Requires=network-online.target
  After=network-online.target
  ConditionFileNotEmpty=/etc/vault.d/vault.hcl

  [Service]
  User=vault
  Group=vault
  ProtectSystem=full
  ProtectHome=read-write
  PrivateTmp=yes
  PrivateDevices=yes
  SecureBits=keep-caps
  AmbientCapabilities=CAP_IPC_LOCK
  Capabilities=CAP_IPC_LOCK+ep
  CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
  NoNewPrivileges=yes
  ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
  ExecReload=/bin/kill --signal HUP $MAINPID
  StandardOutput=/logs/vault/output.log
  StandardError=/logs/vault/error.log
  KillMode=process
  KillSignal=SIGINT
  Restart=on-failure
  RestartSec=5
  TimeoutStopSec=30
  StartLimitIntervalSec=60
  StartLimitBurst=3
  LimitNOFILE=65536

  [Install]
  WantedBy=multi-user.target
EOF

# Create vault configuration, data & logs directory
sudo mkdir -p /etc/vault.d
sudo touch $VAULT_CONFIG_FILE
sudo chown -R vault:vault /etc/vault.d
sudo chmod 640 $VAULT_CONFIG_FILE

sudo mkdir $VAULT_DATA
sudo chown -R vault:vault $VAULT_DATA
sudo mkdir -p /logs/vault/

cat <<EOF >$VAULT_CONFIG_FILE
  ui = true

  listener "tcp" {
    address     = "0.0.0.0:8200"
    tls_disable = true
  }

  storage "file" {
    path = "$VAULT_DATA"
  }

  default_lease_ttl = "168h"
  max_lease_ttl = "0h"
  api_addr = "http://0.0.0.0:8200"
EOF

# Enable, start and check the status of vault service.
sudo systemctl enable vault
sudo systemctl start vault
sudo systemctl status vault
