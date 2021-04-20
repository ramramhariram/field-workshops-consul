#!/bin/bash

#metadata
local_ipv4=$(curl -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2017-08-01&format=text")

#utils
sudo apt-get install -y unzip

#Download Consul
CONSUL_VERSION="1.9.4+ent"
curl --silent --remote-name https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip

#Install Consul
unzip consul_$${CONSUL_VERSION}_linux_amd64.zip
unzip consul-template_$${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip
sudo chown root:root consul
sudo chown root:root consul consul-template
sudo mv consul* /usr/local/bin/
consul -autocomplete-install
complete -C /usr/local/bin/consul consul

#Create Consul User
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul


#Download Vault
VAULT_VERSION="1.7.0+ent"
curl --silent --remote-name https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_amd64.zip

#Install Vault


#Create Vault User

#vault
az login --identity
export VAULT_ADDR="http://$(az vm show -g $(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-08-01" | jq -r '.compute | .resourceGroupName') -n vault-server-vm -d | jq -r .publicIps):8200"
export VAULT_TOKEN=$(vault write -field=token auth/azure/login -field=token role="consul" \
     jwt="$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -H Metadata:true | jq -r '.access_token')")

mkdir -p /etc/vault-agent.d/
mkdir -p /opt/consul/tls/
cat <<EOF> /etc/vault-agent.d/consul-ca-template.ctmpl
{{ with secret "pki/cert/ca" }}
{{ .Data.certificate }}
{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/consul-cert-template.ctmpl
{{ with secret "pki/issue/consul" "common_name=consul-server-0.server.azure-west-us-2.consul" "alt_names=consul-server-0.server.azure-west-us-2.consul,server.azure-west-us-2.consul,localhost" "ip_sans=127.0.0.1" "key_usage=DigitalSignature,KeyEncipherment" "ext_key_usage=ServerAuth,ClientAuth" }}
{{ .Data.certificate }}
{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/consul-key-template.ctmpl
{{ with secret "pki/issue/consul" "common_name=consul-server-0.server.azure-west-us-2.consul" "alt_names=consul-server-0.server.azure-west-us-2.consul,server.azure-west-us-2.consul,localhost" "ip_sans=127.0.0.1" "key_usage=DigitalSignature,KeyEncipherment" "ext_key_usage=ServerAuth,ClientAuth" }}
{{ .Data.private_key }}
{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/consul-acl-template.ctmpl
acl = {
  enabled        = true
  default_policy = "deny"
  down_policy   = "extend-cache"
  enable_token_persistence = true
  enable_token_replication = true
  tokens {
    agent  = {{ with secret "kv/consul" }}"{{ .Data.data.master_token }}"{{ end }}
    replication = {{ with secret "kv/consul" }}"{{ .Data.data.replication_token }}"{{ end }}
  }
}
encrypt = {{ with secret "kv/consul" }}"{{ .Data.data.gossip_key }}"{{ end }}
EOF
cat <<EOF> /etc/vault-agent.d/vault.hcl
pid_file = "/var/run/vault-agent-pidfile"
auto_auth {
  method "azure" {
      mount_path = "auth/azure"
      config = {
          role = "consul"
          resource = "https://management.azure.com/"
      }
  }
}
template {
  source      = "/etc/vault-agent.d/consul-ca-template.ctmpl"
  destination = "/opt/consul/tls/ca-cert.pem"
  command     = "sudo service consul reload"
}
template {
  source      = "/etc/vault-agent.d/consul-cert-template.ctmpl"
  destination = "/opt/consul/tls/server-cert.pem"
  command     = "sudo service consul reload"
}
template {
  source      = "/etc/vault-agent.d/consul-key-template.ctmpl"
  destination = "/opt/consul/tls/server-key.pem"
  command     = "sudo service consul reload"
}
template {
  source      = "/etc/vault-agent.d/consul-acl-template.ctmpl"
  destination = "/etc/consul.d/acl.hcl"
  command     = "sudo service consul reload"
}
vault {
  address = "$${VAULT_ADDR}"
  token   = "$${VAULT_TOKEN}"
}
EOF
cat <<EOF > /etc/systemd/system/vault-agent.service
[Unit]
Description=Envoy
After=network-online.target
Wants=consul.service
[Service]
ExecStart=/usr/bin/vault agent -config=/etc/vault-agent.d/vault.hcl -log-level=debug
Restart=always
RestartSec=5
StartLimitIntervalSec=0
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable vault-agent.service
sudo systemctl start vault-agent.service
sleep 10
#config
cat <<EOF> /etc/consul.d/server.json
{
  "datacenter": "azure-west-us-2",
  "primary_datacenter": "aws-us-east-1",
  "server": true,
  "bootstrap_expect": 1,
  "advertise_addr": "$${local_ipv4}",
  "data_dir": "/opt/consul/data",
  "client_addr": "0.0.0.0",
  "log_level": "INFO",
  "node_name": "consul-server-0",
  "ui": true,
}
EOF
cat <<EOF> /etc/consul.d/tls.json
{
  "verify_incoming": true,
  "verify_outgoing": true,
  "verify_server_hostname": true,
  "ca_file": "/opt/consul/tls/ca-cert.pem",
  "cert_file": "/opt/consul/tls/server-cert.pem",
  "key_file": "/opt/consul/tls/server-key.pem",
  "auto_encrypt": {
    "allow_tls": true
  }
}
EOF