variable "resource_group_name" {
  type    = string
}

variable "location" {
  type    = string
}

variable "storage_account_id" {
  type = string
}

variable "mysql_resource_id" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "vnet_address_space" {
  type = list(string)
}

variable "vnet_name" {
  type = string
}

variable "aks_address_subnet_prefixes" {
  type = list(string)
}

variable "aks_subnet_name" {
  type = string
}

variable "appgw_address_prefixes" {
  type = list(string)
}

variable "azurerm_subnet_name" {
  type = string
}

variable "azurerm_subnet_address_prefixes" {
  type = list(string)
}

variable "appgw_subnet_name" {
  type = string
}