# Replace jdoe with your initials in all three names before deploying.
# Replace a1b2 with your own globally unique lowercase alphanumeric suffix.
# Do not deploy the assignment and this solution against the same Azure names
# using separate state files. Pick different names for an instructor demo.
resource "azurerm_resource_group" "workshop" {
  name     = "rg-terraform-db-workshop-jdoe"
  location = var.location

  tags = {
    environment = var.environment
    workshop    = "terraform"
    training    = "database" # Added in step 4; omit this line for the initial deployment.
  }
}

# Read the existing identity used by Terraform; do not create an Entra user.
# This workshop expects an interactive user signed in through Azure CLI.
data "azurerm_client_config" "current" {}

resource "azurerm_mssql_server" "workshop" {
  name                          = "sql-tfdb-jdoe-${var.environment}-a1b2"
  resource_group_name           = azurerm_resource_group.workshop.name
  location                      = azurerm_resource_group.workshop.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  # Supplied configuration, not an authentication exercise.
  # The object ID identifies the administrator; the username is a display label.
  # Entra-only authentication avoids SQL passwords in the code and state.
  azuread_administrator {
    login_username              = "Workshop participant"
    object_id                   = data.azurerm_client_config.current.object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_database" "workshop" {
  name                 = "sqldb-jdoe-${var.environment}"
  server_id            = azurerm_mssql_server.workshop.id
  sku_name             = var.database_sku
  max_size_gb          = 2
  storage_account_type = "Local"
}
