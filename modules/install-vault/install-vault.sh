#!/bin/bash

###########################################
#
#   Hashicorp Vault Setup on Amazon Ec23
#
###########################################
set -e

export VAULT_ADDR='http://0.0.0.0:8200'

readonly VAULT_VERSION=${VAULT_VERSION}
readonly SYSTEMD_CONFIG_VAULT=/etc/systemd/system/vault.service
readonly VAULT_CONFIG_FILE=/etc/vault.d/vault.hcl

readonly VAULT_DATA=/vault-data

# Vault run params
readonly VAULT_KV_ENGINE=${VAULT_KV_ENGINE}
readonly VAULT_SECRETS_PATH=${VAULT_SECRETS_PATH}
readonly VAULT_AUTH_USER=${VAULT_AUTH_USER}
readonly VAULT_AUTH_PASS=${VAULT_AUTH_PASS}

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

usermod -a -G vault ubuntu

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

###############
#
# Vault run
#
###############

readonly VAULT_CONFIG_PATH=/vault-config
readonly VAULT_POLICY_PATH=/vault-policy

sudo mkdir -p $VAULT_CONFIG_PATH
sudo mkdir -p $VAULT_POLICY_PATH

sudo chmod g+w $VAULT_CONFIG_PATH
sudo chmod g+w $VAULT_POLICY_PATH

sudo chown -R vault:vault $VAULT_CONFIG_PATH
sudo chown -R vault:vault $VAULT_POLICY_PATH

# Vault init
vault operator init \
  -key-shares=6 \
  -key-threshold=3 \
  -address=${VAULT_ADDR} >$VAULT_CONFIG_PATH/keys.txt

export VAULT_TOKEN=$(grep 'Initial Root Token:' $VAULT_CONFIG_PATH/keys.txt | awk '{print substr($NF, 1, length($NF))}')

# Unseal
vault operator unseal -address=${VAULT_ADDR} $(grep 'Key 1:' $VAULT_CONFIG_PATH/keys.txt | awk '{print $NF}')
vault operator unseal -address=${VAULT_ADDR} $(grep 'Key 2:' $VAULT_CONFIG_PATH/keys.txt | awk '{print $NF}')
vault operator unseal -address=${VAULT_ADDR} $(grep 'Key 3:' $VAULT_CONFIG_PATH/keys.txt | awk '{print $NF}')

# Login
vault login $VAULT_TOKEN

# Enable kv
vault secrets enable -version=${VAULT_KV_ENGINE} kv

# Enable userpass
vault auth enable userpass

# Enable approle
vault auth enable approle

# Enable kv engine
vault secrets enable -version=${VAULT_KV_ENGINE} -path=${VAULT_SECRETS_PATH} kv

# Add userpass admin
export POLICY_ADMIN_VAULT_HCL=$VAULT_POLICY_PATH/admin-vault.hcl

# Create admin-vault
touch $POLICY_ADMIN_VAULT_HCL

cat <<EOF >$POLICY_ADMIN_VAULT_HCL
  # Mount the AppRole auth method
  path "sys/auth/approle" {
    capabilities = [ "create", "read", "update", "delete", "sudo" ]
  }

  # Configure the AppRole auth method
  path "sys/auth/approle/*" {
    capabilities = [ "create", "read", "update", "delete" ]
  }

  # Create and manage roles
  path "auth/approle/*" {
    capabilities = [ "create", "read", "update", "delete", "list" ]
  }

  # Write ACL policies
  path "sys/policies/acl/*" {
    capabilities = [ "create", "read", "update", "delete", "list" ]
  }
EOF
vault policy write admin-vault $POLICY_ADMIN_VAULT_HCL

# Create users with policy
vault write auth/userpass/users/${VAULT_AUTH_USER} policies=admin-vault password=${VAULT_AUTH_PASS}
