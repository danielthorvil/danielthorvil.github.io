variable "region" {
  description = "The Azure region to use for all the resources"
  type        = string
}

variable "name-prefix" {
  description = "The prefix used for all the resource names"
  type        = string
}

variable "vnets" {
  description = "The vnet and subnets within that should be created"

  type = list(object({
    name          = string
    address_space = string
    subnets = list(object({
      name           = string
      address_prefix = string
    }))
  }))
}

variable "ip-groups" {
  description = "Contains the Azure IP Groups that should be created."

  type = list(object({
    name  = string
    cidrs = list(string)
  }))
}

variable "ruleCollectionGroups" {
  description = "Variable that contains rule collections AND the rules within"

  type = list(object({
    ruleCollectionGroupName     = string
    ruleCollectionGroupPriority = number

    NetworkRuleCollections = optional(list(object({
      ruleCollectionName     = string
      ruleCollectionPriority = number
      ruleCollectionAction   = string
      rules = list(object({
        name                  = string
        description           = string
        source_addresses      = optional(list(string))
        source_ip_groups      = optional(list(any))
        destination_addresses = optional(list(string))
        destination_ip_groups = optional(list(any))
        destination_fqdns     = optional(list(string))
        protocols             = list(string)
        destination_ports     = list(any)
    })) })))

    ApplicationRuleCollections = optional(list(object({
      ruleCollectionName     = string
      ruleCollectionPriority = number
      ruleCollectionAction   = string
      rules = list(object({
        name              = string
        description       = string
        source_addresses  = optional(list(string))
        source_ip_groups  = optional(list(any))
        destination_fqdns = list(string)
        protocols = list(object({
          port = any
          type = string
        }))
    })) })))
  }))
}