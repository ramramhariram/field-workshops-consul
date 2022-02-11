#!/bin/bash

#metadata
local_ipv4="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"

#dirs
sudo mkdir -p /opt/consul/tls/
sudo chown -R consul:consul /opt/consul/
sudo chown -R consul:consul /etc/consul.d/

#consul
cat <<EOF > /etc/consul.d/consul.hcl
datacenter = "aws-ec2"
primary_datacenter = "aws-ec2"
advertise_addr = "$${local_ipv4}"
client_addr = "0.0.0.0"
node_name = "$${instance}"
ui = true
connect = {
  enabled = true
}
retry_join = ["provider=aws tag_key=Env tag_value=consul-${env}"]
license_path="/etc/consul.d/consul.hclic"
data_dir = "/opt/consul/data"
log_level = "INFO"
ports = {
  grpc = 8502
}
EOF

#start services
sudo systemctl enable consul.service
sudo systemctl start consul.service

#Monitor CTS as a service 

cat << EOF > /etc/consul.d/cts.json
{
  "service": {
    "name": "cts",
    "port": 8558,
    "check": {
      "id": "8558",
      "name": "CTS TCP on port 8558",
      "tcp": "localhost:8558",
      "interval": "5s",
      "timeout": "3s"
    }
  }
}
EOF

#!/bin/bash

#Utils
sudo apt-get install unzip
#Download Consul Terraform Sync
curl --silent --remote-name https://releases.hashicorp.com/consul-terraform-sync/0.4.3/consul-terraform-sync_0.4.3_linux_amd64.zip
unzip consul-terraform-sync_0.4.3_linux_amd64.zip

#Install consul-terraform-sync
sudo chown root:root consul-terraform-sync
sudo mv consul-terraform-sync /usr/local/bin/

#Create Consul Terraform Sync User
#Use if needed, for now, manually enable it. 
#sudo useradd --system --home /etc/consul.d --shell /bin/false consul

sudo mkdir --parents /opt/consul-tf-sync.d
sudo chown --recursive consul:consul /opt/consul-tf-sync.d

#Create Systemd Config for Consul Terraform Sync
#copy and use if needed, for now, manually enable it. 

#Create config dir
#Use if needed, for now, manually enable it. 
sudo mkdir --parents /etc/consul-tf-sync.d
sudo chown --recursive consul:consul /etc/consul-tf-sync.d


#Create Systemd Config for Consul Terraform Sync
sudo cat << EOF > /etc/systemd/system/consul-tf-sync.service
[Unit]
Description="HashiCorp Consul Terraform Sync - A Network Infra Automation solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul-terraform-sync -config-file=/etc/consul-tf-sync.d/cts.hcl
KillMode=process
Restart=always
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

#add cts hcl file 

cat << EOF > /etc/consul-tf-sync.d/cts.hcl

#general
log_level = "INFO"
port = 8558
syslog {}
license_path="/etc/consul.d/consul.hclic"
buffer_period {
  enabled = true
  min = "5s"
  max = "20s"
}
working_dir = "/opt/consul-tf-sync.d/"

#Consul connection
consul {
    address =  "localhost:8500"
}
task {
  name           = "security-group-demo-task"
  description    = "allow all redis TCP traffic from specific source to a security group"
  source         = "github.com/ramramhariram/sg-nia-mc"
  services       = ["aws-us-east-1-terminating-gateway"]
  variable_files = ["/home/ubuntu/security_input.tfvars"]
}

# Terraform Driver Options
driver "terraform" {
  log = true
  path = "/opt/consul-tf-sync.d/"
  working_dir = "/opt/consul-tf-sync.d/"
}

EOF

#Enable the services
sudo systemctl enable consul
sudo service consul start
sudo service consul status
sudo systemctl enable consul-tf-sync
sudo service consul-tf-sync start
sudo service consul-tf-sync status


