### Azure prerequisites ###
# Create resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.name-prefix}-rg"
  location = var.region
}

### Azure Firewall ###
# Public IP for management
resource "azurerm_public_ip" "azfw-management-pup-ip" {
  name                = "${var.name-prefix}-azfw-management-pup-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Public IP for data
resource "azurerm_public_ip" "azfw-data-pup-ip" {
  name                = "${var.name-prefix}-azfw-data-pup-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure Firewall policy
resource "azurerm_firewall_policy" "azfw_policy" {
  name                     = "${var.name-prefix}-azfw-policy"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.region
  sku                      = "Basic"
  threat_intelligence_mode = "Alert"
}

# IP Groups
resource "azurerm_ip_group" "ip_groups" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region

  for_each = { for ipgroup in var.ip-groups : ipgroup.name => ipgroup.cidrs }

  name  = each.key
  cidrs = each.value
}

locals {
  # Used for lookup in the azurerm_firewall_policy_rule_collection_group.azfw_rules resource.
  ip_group_mapping = { for ip_group in azurerm_ip_group.ip_groups : ip_group.name => ip_group.id }
}

# Rule collection groups, rule collections, rules
resource "azurerm_firewall_policy_rule_collection_group" "azfw_rules" {
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id

  for_each = { for ruleCollectionGroup in var.ruleCollectionGroups : ruleCollectionGroup.ruleCollectionGroupName => ruleCollectionGroup }

  name     = each.key
  priority = each.value.ruleCollectionGroupPriority

  dynamic "network_rule_collection" {
    for_each = { for ruleCollection in coalesce(each.value.NetworkRuleCollections, []) : ruleCollection.ruleCollectionName => ruleCollection }

    content {
      name     = network_rule_collection.value.ruleCollectionName
      priority = network_rule_collection.value.ruleCollectionPriority
      action   = network_rule_collection.value.ruleCollectionAction

      dynamic "rule" {
        for_each = { for rule in network_rule_collection.value.rules : rule.name => rule }

        content {
          name                  = rule.value.name
          description           = rule.value.description
          source_addresses      = rule.value.source_addresses
          source_ip_groups      = [for ip_group in coalesce(rule.value.source_ip_groups, []) : lookup(local.ip_group_mapping, ip_group)]
          destination_addresses = rule.value.destination_addresses
          destination_ip_groups = [for ip_group in coalesce(rule.value.destination_ip_groups, []) : lookup(local.ip_group_mapping, ip_group)]
          destination_fqdns     = rule.value.destination_fqdns
          protocols             = rule.value.protocols
          destination_ports     = rule.value.destination_ports
        }
      }
    }
  }

  dynamic "application_rule_collection" {
    for_each = { for ruleCollection in coalesce(each.value.ApplicationRuleCollections, []) : ruleCollection.ruleCollectionName => ruleCollection if ruleCollection.ruleCollectionName != null }

    content {
      name     = application_rule_collection.value.ruleCollectionName
      priority = application_rule_collection.value.ruleCollectionPriority
      action   = application_rule_collection.value.ruleCollectionAction

      dynamic "rule" {
        for_each = { for rule in application_rule_collection.value.rules : rule.name => rule }

        content {
          name              = rule.value.name
          description       = rule.value.description
          source_addresses  = rule.value.source_addresses
          source_ip_groups  = [for ip_group in coalesce(rule.value.source_ip_groups, []) : lookup(local.ip_group_mapping, ip_group)]
          destination_fqdns = rule.value.destination_fqdns
          dynamic "protocols" {
            for_each = { for protocol in rule.value.protocols : "test" => protocol }

            content {
              type = protocols.value.type
              port = protocols.value.port
            }
          }
        }
      }
    }
  }
}

# Azure Firewall
#resource "azurerm_firewall" "azfw" {
#  name                = "${var.name-prefix}-azfw"
#  location            = var.region
#  resource_group_name = azurerm_resource_group.rg.name
#  sku_name            = "AZFW_VNet"
#  sku_tier            = "Basic"
#
#  ip_configuration {
#    name                 = "data-ip-configuration"
#    subnet_id            = [for subnet in azurerm_virtual_network.vnets["vnet-hub"].subnet : subnet.id if subnet.name == "AzureFirewallSubnet"][0]
#    public_ip_address_id = azurerm_public_ip.azfw-data-pup-ip.id
#  }
#
#  management_ip_configuration {
#    name                 = "management-ip-configuration"
#    subnet_id            = [for subnet in azurerm_virtual_network.vnets["vnet-hub"].subnet : subnet.id if subnet.name == "AzureFirewallManagementSubnet"][0]
#    public_ip_address_id = azurerm_public_ip.azfw-management-pup-ip.id
#  }
#
#  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
#
#}

### Hub and spoke networking ###
# Create VNets and subnets within
resource "azurerm_virtual_network" "vnets" {
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

  for_each      = { for vnet in var.vnets : vnet.name => vnet }
  name          = each.value.name
  address_space = [each.value.address_space]

  dynamic "subnet" {
    for_each = each.value.subnets
    content {
      name           = subnet.value.name
      address_prefix = subnet.value.address_prefix
    }
  }
}

# Peering from hub to spokes
resource "azurerm_virtual_network_peering" "to-spoke-peerings" {
  resource_group_name = azurerm_resource_group.rg.name

  for_each = { for spoke in azurerm_virtual_network.vnets : spoke.name => spoke if can(regex("spoke", spoke.name)) }

  name                      = "vnet-hub-to-${each.value.name}"
  virtual_network_name      = "vnet-hub"
  remote_virtual_network_id = each.value.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}

# Peering from spokes to hub
resource "azurerm_virtual_network_peering" "to-hub-peerings" {
  resource_group_name = azurerm_resource_group.rg.name

  for_each = { for spoke in azurerm_virtual_network.vnets : spoke.name => spoke if can(regex("spoke", spoke.name)) }

  name                      = "${each.value.name}-to-vnet-hub"
  virtual_network_name      = each.value.name
  remote_virtual_network_id = azurerm_virtual_network.vnets["vnet-hub"].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}