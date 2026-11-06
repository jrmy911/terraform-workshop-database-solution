output "resource_group_name" {
  description = "The workshop resource group name."
  value       = azurerm_resource_group.workshop.name
}

output "sql_server_fqdn" {
  description = "The SQL server hostname; SQL connectivity is deliberately not configured."
  value       = azurerm_mssql_server.workshop.fully_qualified_domain_name
}

output "database_name" {
  description = "The workshop database name."
  value       = azurerm_mssql_database.workshop.name
}
