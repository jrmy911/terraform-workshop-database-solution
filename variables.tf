variable "environment" {
  description = "The environment label used in SQL resource names and the resource group tag."
  type        = string
}

variable "location" {
  description = "The Azure region for the workshop resources."
  type        = string
  default     = "westeurope"
}

variable "database_sku" {
  description = "The database service tier: Basic for the sandbox, S0 for a preview-only plan."
  type        = string
  default     = "Basic"
}
