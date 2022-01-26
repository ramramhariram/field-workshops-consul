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
#sudo mkdir --parents /opt/consul-tf-sync.d
#sudo chown --recursive consul:consul /opt/consul-tf-sync.d

#Create Systemd Config for Consul Terraform Sync
#copy and use if needed, for now, manually enable it. 

#Create config dir
#Use if needed, for now, manually enable it. 
#sudo mkdir --parents /etc/consul-tf-sync.d
#sudo chown --recursive consul:consul /etc/consul-tf-sync.d

