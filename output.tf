output "subnet_id" {
  value = azurerm_subnet.subnet.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.sub-aks.id
}

output "application_gateway_id" {
  value = azurerm_application_gateway.gateway.id
}
