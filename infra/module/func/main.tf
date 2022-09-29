### INPUT VARs ###
variable "REGION" {
  description = "Azure region"
  type        = string
}
variable "RESOURCE_GROUP" {
  description = "Please enter the resource group for the storage account"
}
variable "STORAGE_ACC_NAME" {
  description = "Please enter a unique name for this storage account"
}
# variable "STORAGE_ACC_KEY" {
#   description = "Please enter a storage account key"
# }

variable "naming_prefix" {
  type    = string
  default = "nepre"
}
# variable "STORAGE_CONNECTION_STRING" {}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_subscription" "current" {
}

resource "azurerm_resource_group" "func-rg" {
  name     = var.RESOURCE_GROUP
  location = var.REGION
}

resource "azurerm_application_insights" "func_app_insights" {
  name                = "nep-application-insights"
  location            = var.REGION
  resource_group_name = azurerm_resource_group.func-rg.name
  application_type    = "Node.JS"
}

resource "azurerm_app_service_plan" "func_app_service_plan" {
  name                = "nep-funcapp-service-plan"
  location            = var.REGION
  resource_group_name = azurerm_resource_group.func-rg.name
  kind                = "FunctionApp"
  reserved            = true
  sku {
    tier = "Standard"
    size = "S1"
  }

}

resource "azurerm_function_app" "neptune_prd_azfunc" {
  name                = "neptunefunc-application"
  location            = var.REGION
  resource_group_name = azurerm_resource_group.func-rg.name
  app_service_plan_id = azurerm_app_service_plan.func_app_service_plan.id
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "node",
    # AzureWebJobsStorage      = azurerm_storage_account.storeblb.primary_blob_container
    # var.STORAGE_CONNECTION_STRING,
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.func_app_insights.instrumentation_key,
    WEBSITE_RUN_FROM_PACKAGE       = "1"
  }

  os_type              = "linux"
  storage_account_name = azurerm_storage_account.storeblb.name
  #   var.STORAGE_ACC_NAME
  storage_account_access_key = azurerm_storage_account.storeblb.primary_access_key
  #   var.STORAGE_ACC_KEY
  version = "~3"

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"]
    ]
  }

  identity {
    type = "SystemAssigned"
  }

  site_config {
    cors {
      allowed_origins = ["*"]
    }
  }
}

resource "azurerm_role_assignment" "neptune_prd_azfunc" {
  principal_id         = azurerm_function_app.neptune_prd_azfunc.identity[0].principal_id
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Owner"
  # ${data.azurerm_subscription.current.id}${data.azurerm_role_definition.contributor.id}

  depends_on = [
    azurerm_function_app.neptune_prd_azfunc
  ]
}

# resource "random_string" "random" {
#   length  = 4
#   special = false
#   lower   = true
#   upper   = false
# }

resource "random_integer" "sa_num" {
  min = 10000
  max = 99999
}

# Blob Storage Account
resource "azurerm_storage_account" "storeblb" {
  name                     = "${lower(var.naming_prefix)}${random_integer.sa_num.result}"
  resource_group_name      = azurerm_resource_group.func-rg.name
  location                 = var.REGION
  account_tier             = "Standard"
  account_replication_type = "LRS"

  depends_on = [
    azurerm_resource_group.func-rg
  ]
}

resource "azurerm_storage_container" "storeblb" {
  name                  = "storecontentblb"
  storage_account_name  = azurerm_storage_account.storeblb.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "storeblb" {
  name                   = "neptunedevblob"
  storage_account_name   = azurerm_storage_account.storeblb.name
  storage_container_name = azurerm_storage_container.storeblb.name
  type                   = "Block"
  #   source                 = "some-local-file.zip"
}

# DataFactory
resource "azurerm_data_factory" "exampleadf" {
  name                = "neptune-adf"
  location            = var.REGION
  resource_group_name = azurerm_resource_group.func-rg.name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "exampleadf" {
  principal_id         = azurerm_data_factory.exampleadf.identity[0].principal_id
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Owner"

  depends_on = [
    azurerm_data_factory.exampleadf
  ]
}

# Data Lake Gen2
resource "azurerm_storage_account" "stordalagen2" {
  name                     = "neptunestorageaccdl"
  resource_group_name      = azurerm_resource_group.func-rg.name
  location                 = var.REGION
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"

  depends_on = [
    azurerm_resource_group.func-rg
  ]
}

resource "azurerm_storage_data_lake_gen2_filesystem" "stordalagen2" {
  name               = "neptune-dl"
  storage_account_id = azurerm_storage_account.stordalagen2.id

  properties = {
    hello = "aGVsbG8="
  }
}