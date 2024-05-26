region      = "West Europe"
name-prefix = "test-tf-azfwipgrps"

vnets = [{
  name          = "vnet-hub"
  address_space = "10.10.0.0/16"
  subnets = [{
    name           = "subnet01"
    address_prefix = "10.10.10.0/24"
    },
    {
      name           = "AzureFirewallManagementSubnet"
      address_prefix = "10.10.20.0/24"
    },
    {
      name           = "AzureFirewallSubnet"
      address_prefix = "10.10.30.0/24"
  }]
  },
  {
    name          = "vnet-spoke01"
    address_space = "10.69.0.0/16"
    subnets = [{
      name           = "subnet01"
      address_prefix = "10.69.10.0/24"
      },
      {
        name           = "subnet02"
        address_prefix = "10.69.20.0/24"
      }
    ]
  },
  {
    name          = "vnet-spoke02"
    address_space = "10.70.0.0/16"
    subnets = [{
      name           = "subnet01"
      address_prefix = "10.70.10.0/24"
      },
      {
        name           = "subnet02"
        address_prefix = "10.70.20.0/24"
    }]
}]

ip-groups = [
  {
    name  = "cloudflareDnsResolvers"
    cidrs = ["1.1.1.0/29", "1.0.0.0/29"]
  },
  {
    name  = "googleDnsResolvers"
    cidrs = ["8.8.8.8/32", "8.8.4.4/32"]
  },
  {
    name  = "localNetworkSpoke01Subnet01"
    cidrs = ["10.69.10.0/24"]
}]

ruleCollectionGroups = [{
  ruleCollectionGroupName     = "ruleCollectionGroup01"
  ruleCollectionGroupPriority = 120

  NetworkRuleCollections = [{
    ruleCollectionName     = "networkRuleCollection01"
    ruleCollectionPriority = 150
    ruleCollectionAction   = "Allow"
    rules = [{
      name                  = "rule01"
      description           = "description"
      source_addresses      = ["10.69.69.0/24"]
      destination_addresses = ["66.66.66.0/32"]
      protocols             = ["ICMP"]
      destination_ports     = ["*"]
      },
      {
        name                  = "rule02"
        description           = "description"
        source_addresses      = ["10.69.69.0/24"]
        destination_addresses = ["65.34.23.4/32"]
        protocols             = ["TCP"]
        destination_ports     = ["443"]
    }]
  }]

  ApplicationRuleCollections = [{
    ruleCollectionName     = "applicationRuleCollection01"
    ruleCollectionPriority = 160
    ruleCollectionAction   = "Allow"
    rules = [{
      name              = "rule01"
      description       = "description"
      source_addresses  = ["10.66.66.0/24"]
      destination_fqdns = ["google.com"]
      protocols         = [{ type = "Https", port = 443 }]
      },
      {
        name              = "rule02"
        description       = "description"
        source_addresses  = ["10.66.66.0/24"]
        destination_fqdns = ["facebook.com"]
        protocols         = [{ type = "Http", port = 80 }]
    }]
  }]
  },
  {
    ruleCollectionGroupName     = "ruleCollectionGroup02"
    ruleCollectionGroupPriority = 120

    NetworkRuleCollections = [{
      ruleCollectionName     = "networkRuleCollection02"
      ruleCollectionPriority = 150
      ruleCollectionAction   = "Allow"
      rules = [{
        name                  = "rule01"
        description           = "description"
        source_addresses      = ["10.69.69.0/24"]
        destination_ip_groups = ["cloudflareDnsResolvers", "googleDnsResolvers"]
        protocols             = ["TCP", "UDP"]
        destination_ports     = ["53"]
      }]
    }]

    ApplicationRuleCollections = [{
      ruleCollectionName     = "applicationRuleCollection02"
      ruleCollectionPriority = 160
      ruleCollectionAction   = "Allow"
      rules = [
        {
          name              = "rule01"
          description       = "description"
          source_ip_groups  = ["localNetworkSpoke01Subnet01"]
          destination_fqdns = ["youtube.com"]
          protocols         = [{ type = "Http", port = 80 }]
      }]
    }]
}]