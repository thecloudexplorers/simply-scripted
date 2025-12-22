# Service Groups Hierarchy Deployment

## Overview
Deploys an Azure service group hierarchy (public preview) at tenant scope. The
template layers up to 10 tiers of service groups, ensuring each child waits for
its parent tier before creation. Tenant root is automatically used as the parent
for Tier 1.

## Template
- Main template:
  [iac/az-controllers/serviceGroupsHierarchy.bicep](iac/az-controllers/serviceGroupsHierarchy.bicep)
- Child module:
  [iac/az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep](iac/az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep)
- Sample parameters:
  [params/serviceGroupsHierarchy.json](params/serviceGroupsHierarchy.json)

## Parameters
Each tier parameter is an array of objects. All properties are required unless
noted.

| Parameter | Structure | Notes |
| --- | --- | --- |
| tier01ServiceGroups | [{ id, displayName }] | Parent defaults to tenant root. |
| tier02ServiceGroups … tier10ServiceGroups | [{ id, displayName, parentId }] | `parentId` must match an `id` from an earlier tier. Leave arrays empty when unused. |

## Expected object shape
```json
{
  "id": "ContosoCorp.Departments",
  "displayName": "Departments",
  "parentId": "ContosoCorp" // omit for Tier 1
}
```
- `id`: 1–243 chars, letters/digits/-_().~ only; must be globally unique.
- `displayName`: Friendly name shown in the portal.
- `parentId`: Required for tiers 2–10; matches the parent's `id`.

## Deployment
Choose a supported Azure region for the deployment location (tenant deployments
still require a location flag).

### Azure CLI
```bash
az deployment tenant create \
  --name serviceGroupsHierarchy \
  --location eastus \
  --template-file iac/az-controllers/serviceGroupsHierarchy.bicep \
  --parameters @params/serviceGroupsHierarchy.json
```

### PowerShell (Az)
```powershell
$deployParams = @{
    Name                  = 'serviceGroupsHierarchy'
    Location              = 'eastus'
    TemplateFile          = 'iac/az-controllers/serviceGroupsHierarchy.bicep'
    TemplateParameterFile = 'params/serviceGroupsHierarchy.json'
}
New-AzTenantDeployment @deployParams
```
```

## Notes
- Resource type `Microsoft.Management/serviceGroups` is currently in preview; ensure the tenant is enabled for this provider.
- The template has no outputs; verification is via the service groups blade or `az rest` against the management endpoint.
