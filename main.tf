terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "2.4.0"
    }
  }
}

provider "azapi" {}

resource "azapi_resource" "custom_network_contributor_role_definition" {
  type      = "Microsoft.Authorization/roleDefinitions@2022-05-01-preview"
  parent_id = provider::azapi::tenant_resource_id("Microsoft.Management/managementGroups", ["root"])
  name      = uuidv5("oid", "Lindbergtech Custom Network Contributor Role")
  body = {
    properties = {
      assignableScopes = [
        provider::azapi::tenant_resource_id("Microsoft.Management/managementGroups", ["root"])
      ]
      description = "This is a custom network contributor role for Lindbergtech"
      permissions = [
        {
          actions = [
            "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
            "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
            "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read"
          ]
        }
      ]
      roleName = "Lindbergtech Custom Network Contributor"
      type     = "CustomRole"
    }
  }
  response_export_values    = ["*"]
  schema_validation_enabled = false
}

data "azapi_resource" "uami" {
  type                   = "Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30"
  resource_id            = provider::azapi::resource_group_resource_id("<your-sub-id>", "rg-prd-sc-uami", "Microsoft.ManagedIdentity/userAssignedIdentities", ["uami-prd-sc-azapifunctions"])
  response_export_values = ["properties.principalId"]
}

resource "azapi_resource" "custom_network_contributor_role_assignment" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = "/subscriptions/<your-sub-id>"
  name      = uuidv5("oid", data.azapi_resource.uami.output.properties.principalId)
  body = {
    properties = {
      roleDefinitionId = provider::azapi::tenant_resource_id("Microsoft.Authorization/roleDefinitions", [azapi_resource.custom_network_contributor_role_definition.name])
      principalId      = data.azapi_resource.uami.output.properties.principalId
      principalType    = "ServicePrincipal"
    }
  }
  response_export_values    = ["*"]
  schema_validation_enabled = false
}

resource "azapi_resource" "owner_with_abac" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = "/subscriptions/<your-sub-id>"
  name      = uuidv5("oid", "customownerwithabac")
  body = {
    properties = {
      roleDefinitionId = provider::azapi::tenant_resource_id("Microsoft.Authorization/roleDefinitions", ["8e3af657-a8ff-443c-a75c-2fe8c4bcb635"])
      principalId      = data.azapi_resource.uami.output.properties.principalId
      principalType    = "ServicePrincipal"
      condition        = <<EOF
(
 (
  !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
 )
 OR 
 (
  @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168}
 )
)
AND
(
 (
  !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
 )
 OR 
 (
  @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168}
 )
)
EOF
      conditionVersion = "2.0"
    }
  }
}
