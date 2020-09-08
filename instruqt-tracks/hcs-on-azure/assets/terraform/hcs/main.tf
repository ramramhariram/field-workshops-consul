provider "azurerm" {
  features {}
}

data "terraform_remote_state" "vnet" {
  backend = "local"

  config = {
    path = "../vnet/terraform.tfstate"
  }
}

resource "azurerm_marketplace_agreement" "hcs" {
  count     = var.accept_marketplace_aggrement ? 1 : 0
  publisher = "hashicorp-4665790"
  offer     = "hcs-production"
  plan      = "on-demand"
}

resource "random_string" "storageaccountname" {
  length  = 13
  upper   = false
  lower   = true
  special = false
}

resource "random_string" "blobcontainername" {
  length  = 13
  upper   = false
  lower   = true
  special = false
}

resource "azurerm_managed_application" "hcs" {
  depends_on = [azurerm_marketplace_agreement.hcs]

  name                        = "hcs"
  location                    = data.terraform_remote_state.vnet.outputs.resource_group_location
  resource_group_name         = data.terraform_remote_state.vnet.outputs.resource_group_name
  kind                        = "MarketPlace"
  managed_resource_group_name = "${data.terraform_remote_state.vnet.outputs.resource_group_name}-mrg-hcs"

  plan {
    name      = "on-demand"
    product   = "hcs-production"
    publisher = "hashicorp-4665790"
    version   = "0.0.39"
  }

  parameters = {
    initialConsulVersion  = var.consul_version
    storageAccountName    = "${random_string.storageaccountname.result}"
    blobContainerName     = "${random_string.blobcontainername.result}"
    clusterMode           = "DEVELOPMENT"
    clusterName           = "hashicorp-consul-cluster"
    consulDataCenter      = "east-us"
    numServers            = "1"
    numServersDevelopment = "1"
    automaticUpgrades     = "disabled"
    consulConnect         = "enabled"
    externalEndpoint      = "enabled"
    snapshotInterval      = "1d"
    snapshotRetention     = "1m"
    consulVnetCidr        = "10.0.0.0/24"
    location              = data.terraform_remote_state.vnet.outputs.resource_group_location
    providerBaseURL       = "https://ama-api.hashicorp.cloud/consulama/2020-07-09"
    email                 = "lance@hashicorp.com"
  }
}

module "az-cli" {
  source = "matti/resource/shell"
  depends_on = [azurerm_managed_application.hcs]

  environment = {
    RESOURCE_GROUP = "${data.terraform_remote_state.vnet.outputs.resource_group_name}-mrg-hcs"
  }
  command = "az network vnet list --resource-group $RESOURCE_GROUP | jq -r .[].name"
}

data "azurerm_virtual_network" "hcs" {
  depends_on          = [azurerm_managed_application.hcs]
  name                = module.az-cli.stdout
  resource_group_name = "${data.terraform_remote_state.vnet.outputs.resource_group_name}-mrg-hcs"
}

resource "azurerm_virtual_network_peering" "hcs-frontend" {
  lifecycle {
    ignore_changes = [remote_virtual_network_id]
  }
  depends_on = [azurerm_managed_application.hcs]

  name                      = "HCSToFrontend"
  resource_group_name       = "${data.terraform_remote_state.vnet.outputs.resource_group_name}-mrg-hcs"
  virtual_network_name      = module.az-cli.stdout
  remote_virtual_network_id = data.terraform_remote_state.vnet.outputs.frontend_vnet
}

resource "azurerm_virtual_network_peering" "frontend-hcs" {
  lifecycle {
    ignore_changes = [remote_virtual_network_id]
  }
  depends_on = [azurerm_managed_application.hcs]

  name                      = "FrontendToHCS"
  resource_group_name       = data.terraform_remote_state.vnet.outputs.resource_group_name
  virtual_network_name      = "frontend-vnet"
  remote_virtual_network_id = data.azurerm_virtual_network.hcs.id
}

resource "azurerm_virtual_network_peering" "hcs-backend" {
  lifecycle {
    ignore_changes = [remote_virtual_network_id]
  }
  depends_on = [azurerm_managed_application.hcs]

  name                      = "HCSToBackend"
  resource_group_name       = "${data.terraform_remote_state.vnet.outputs.resource_group_name}-mrg-hcs"
  virtual_network_name      = module.az-cli.stdout
  remote_virtual_network_id = data.terraform_remote_state.vnet.outputs.backend_vnet
}

resource "azurerm_virtual_network_peering" "backend-hcs" {
  lifecycle {
    ignore_changes = [remote_virtual_network_id]
  }
  depends_on = [azurerm_managed_application.hcs]

  name                      = "BackendToHCS"
  resource_group_name       = data.terraform_remote_state.vnet.outputs.resource_group_name
  virtual_network_name      = "backend-vnet"
  remote_virtual_network_id = data.azurerm_virtual_network.hcs.id
}
