##################################################################################
#                              Vnet & Subnets                                    #
##################################################################################
resource "azurerm_virtual_network" "Vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
}

resource "azurerm_subnet" "sub-aks" {
  name                 = var.aks_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.Vnet.name
  address_prefixes     = var.aks_address_subnet_prefixes
}

resource "azurerm_subnet" "sub-appgw" {
  name                 = var.appgw_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.Vnet.name
  address_prefixes     = var.appgw_address_prefixes
}

resource "azurerm_subnet" "subnet" {
  name                 = var.azurerm_subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.Vnet.name
  address_prefixes     = var.azurerm_subnet_address_prefixes
}

##################################################################################
#                               Private Endpoints                                #
##################################################################################
// Private Endpoint mysql
resource "azurerm_private_dns_zone" "pv_dns" {
name                = "mysql.database.azure.com"
resource_group_name = var.resource_group_name
}

resource "azurerm_private_endpoint" "mysql-endpoint" {
  name                = "mysql-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.subnet.id

  private_service_connection {
    name                           = "mysql-pc"
    private_connection_resource_id = var.mysql_resource_id
    subresource_names              = ["mysqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                  = "default"
     private_dns_zone_ids  = [azurerm_private_dns_zone.pv_dns.id]
   }
}

//DNS Zones
resource "azurerm_private_dns_zone" "pv_st_dns" {
  name                = "file.core.windows.net"
  resource_group_name = var.resource_group_name
}

// Private Endpoint storage
resource "azurerm_private_endpoint" "storage-endpoint" {
  name                = "stc-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.subnet.id
  private_service_connection {
    name                           = "storage-pc"
    private_connection_resource_id = var.storage_account_id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

}

# Create a Private DNS to VNET link
resource "azurerm_private_dns_zone_virtual_network_link" "dns-zone-to-vnet-link" {
  name                  = "vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.pv_dns.name
  virtual_network_id    = azurerm_virtual_network.Vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "st-dns-zone-to-vnet-link" {
  name                  = "st-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.pv_st_dns.name
  virtual_network_id    = azurerm_virtual_network.Vnet.id
}


resource "azurerm_private_dns_a_record" "stfilerecord" {
  name                = var.storage_account_name
  zone_name           = azurerm_private_dns_zone.pv_st_dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage-endpoint.private_service_connection[0].private_ip_address]
}

##################################################################################
#                                  GATEWAYS                                      #
##################################################################################

resource "azurerm_public_ip" "gateway" {
  name                    = "gw-pip"
  resource_group_name     = var.resource_group_name
  location                = var.location
  allocation_method       = "Static"
  sku                     = "Standard"
  ip_version              = "IPv4"
  idle_timeout_in_minutes = 4
  zones                   = ["1", "2", "3"]
}

resource "azurerm_application_gateway" "gateway" {
  name                = "agic-appgw"
  resource_group_name = var.resource_group_name
  location            = var.location
  enable_http2        = false
  sku {
    name = "Standard_Small"
    tier = "v2"
  }

  autoscale_configuration {
    min_capacity = "1"
    max_capacity = "2"
  }

  zones = ["1", "2", "3"]

  gateway_ip_configuration {
    name      = "gw-ip-conf"
    subnet_id = azurerm_subnet.sub-appgw.id

  }

  frontend_ip_configuration {
    name                 = "fe-ip"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  frontend_port {
    name = "fe-port"
    port = 80
  }

  backend_http_settings {
    name                  = "http-setting"
    cookie_based_affinity = "Disabled"
    protocol              = "Http"
    port                  = 80
    request_timeout       = 1
  }

  backend_address_pool {
    name  = "backpool"
  }

  http_listener {
    name                           = "listener"
    frontend_ip_configuration_name = "fe-ip"
    frontend_port_name             = "fe-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "listener"
    backend_address_pool_name  = "backpool"
    backend_http_settings_name = "http-setting"
    priority                   = "1000"
  }

}

