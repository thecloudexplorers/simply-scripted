# simply-scripted

This repo is a collection of automation snippets for Azure, Azure DevOps, and supporting tooling. The repo includes
Bicep controllers and modules, PowerShell deployment scripts and functions, and Azure DevOps pipeline decorator
examples.

## Bicep controllers (composed deployments)
- [iac/az-controllers/bastionJumpBox.bicep](iac/az-controllers/bastionJumpBox.bicep) - Bastion host, jump box VM, NICs,
  vNet/subnets, NSGs, PIP, and Key Vault with secrets. - QuickStart guide in
  [iac/az-controllers/bastionJumpBox.md](iac/az-controllers/bastionJumpBox.md).
- [iac/az-controllers/serverVM.bicep](iac/az-controllers/serverVM.bicep) - Adds a server VM with NIC and subnet into an
  existing vNet.
- [iac/az-controllers/managementGroupHierarchy.bicep](iac/az-controllers/managementGroupHierarchy.bicep) - Deploys a
  CAF-inspired management group hierarchy (up to six tiers) plus optional default MG and creation policy.
- [iac/az-controllers/serviceGroupsHierarchy.bicep](iac/az-controllers/serviceGroupsHierarchy.bicep) - Deploys Azure
  Service Groups (preview) in up to ten tiers. Details in
  [iac/az-controllers/serviceGroupsHierarchy.md](iac/az-controllers/serviceGroupsHierarchy.md).

Sample parameter files live in [params](params) (for example
[params/serviceGroupsHierarchy.json](params/serviceGroupsHierarchy.json)).

## Bicep modules (building blocks)
Located under [iac/az-modules](iac/az-modules), covering:
- **Microsoft.Management**:
  [managementGroup.bicep](iac/az-modules/managementGroup.bicep),
  [serviceGroup.bicep](iac/az-modules/serviceGroup.bicep)
- **Microsoft.Network**:
  [virtualNetwork.bicep](iac/az-modules/virtualNetwork.bicep),
  [subnet.bicep](iac/az-modules/subnet.bicep),
  [networkSecurityGroup.bicep](iac/az-modules/networkSecurityGroup.bicep),
  [publicIPAddress.bicep](iac/az-modules/publicIPAddress.bicep),
  [networkInterface.bicep](iac/az-modules/networkInterface.bicep),
  [bastionHost.bicep](iac/az-modules/bastionHost.bicep)
- **Microsoft.Compute**:
  [virtualMachine.bicep](iac/az-modules/virtualMachine.bicep)
- **Microsoft.KeyVault**: [vault.bicep](iac/az-modules/vault.bicep),
  [secret.bicep](iac/az-modules/secret.bicep)
- **Microsoft.ContainerRegistry**:
  [registry.bicep](iac/az-modules/registry.bicep)
- **Utilities**: [resourceId.bicep](iac/az-modules/resourceId.bicep),
  [timestamp.bicep](iac/az-modules/timestamp.bicep)

## PowerShell
Deployment helpers for standing up the labs, managing configuration, and reusable functions for Azure/Entra, Azure
DevOps, and Graph automation.

Deployment scripts:
- [powershell/deployBastionJumpBox.ps1](powershell/deployBastionJumpBox.ps1),
- [powershell/deployServerVm.ps1](powershell/deployServerVm.ps1),
- [powershell/deployBasicRegistry.ps1](powershell/deployBasicRegistry.ps1),
- [powershell/replaceConfigurationFilesTokens.ps1](powershell/replaceConfigurationFilesTokens.ps1),
- [powershell/getAllAzRoleAssignments.ps1](powershell/getAllAzRoleAssignments.ps1).

Function library in [powershell/functions](powershell/functions):
- [Add-EnIdApplicationOwnerInBulk.ps1](powershell/functions/Add-EnIdApplicationOwnerInBulk.ps1)
- [Confirm-AdoGroupMembership.ps1](powershell/functions/Confirm-AdoGroupMembership.ps1)
- [Connect-AzInAppRegistrationContext.ps1](powershell/functions/Connect-AzInAppRegistrationContext.ps1)
- [Connect-MgGraphWithCurrentAzContext.ps1](powershell/functions/Connect-MgGraphWithCurrentAzContext.ps1)
- [Convert-TokensToValues.ps1](powershell/functions/Convert-TokensToValues.ps1)
- [ConvertFrom-SecureStringToPlainText.ps1](powershell/functions/ConvertFrom-SecureStringToPlainText.ps1)
- [Export-AzRoleAssignmentsWithPrincipalNames.ps1](powershell/functions/Export-AzRoleAssignmentsWithPrincipalNames.ps1)
- [Get-FileHashDownload.ps1](powershell/functions/Get-FileHashDownload.ps1)
- [Get-MgGraphToken.ps1](powershell/functions/Get-MgGraphToken.ps1)
- [Get-SubscriptionsFromManagementGroupAncestorsChain.ps1](powershell/functions/Get-SubscriptionsFromManagementGroupAncestorsChain.ps1)
- [New-AdoArmServiceConnection.ps1](powershell/functions/New-AdoArmServiceConnection.ps1)
- [New-AdoAuthenticationToken.ps1](powershell/functions/New-AdoAuthenticationToken.ps1)
- [New-AdoProject.ps1](powershell/functions/New-AdoProject.ps1)
- [New-TenantRootAssignment.ps1](powershell/functions/New-TenantRootAssignment.ps1)
- [Read-AdoOrganizationAdvancedSecurityStatus.ps1](powershell/functions/Read-AdoOrganizationAdvancedSecurityStatus.ps1)
- [Read-AdoOrganizationDefaultLicenseType.ps1](powershell/functions/Read-AdoOrganizationDefaultLicenseType.ps1)
- [Read-AdoOrganizationGeneralBillingSettings.ps1](powershell/functions/Read-AdoOrganizationGeneralBillingSettings.ps1)
- [Read-AdoOrganizationGeneralOverview.ps1](powershell/functions/Read-AdoOrganizationGeneralOverview.ps1)
- [Read-AdoOrganizationPipelinesSettings.ps1](powershell/functions/Read-AdoOrganizationPipelinesSettings.ps1)
- [Read-AdoOrganizationSecurityPolicies.ps1](powershell/functions/Read-AdoOrganizationSecurityPolicies.ps1)
- [Read-AdoRepoAdvancedSecurityStatus.ps1](powershell/functions/Read-AdoRepoAdvancedSecurityStatus.ps1)
- [Read-AdoTenantOrganizationConnections.ps1](powershell/functions/Read-AdoTenantOrganizationConnections.ps1)
- [Remove-SoftDeletedApiManagementInstance.ps1](powershell/functions/Remove-SoftDeletedApiManagementInstance.ps1)
- [Set-AdoAuditStream.ps1](powershell/functions/Set-AdoAuditStream.ps1)
- [Set-AzRoleAssignments.ps1](powershell/functions/Set-AzRoleAssignments.ps1)
- [Set-EnIdApps.ps1](powershell/functions/Set-EnIdApps.ps1)
- [Set-EnIdGroups.ps1](powershell/functions/Set-EnIdGroups.ps1)
- [Test-AdoServiceConnection.ps1](powershell/functions/Test-AdoServiceConnection.ps1)

## Azure DevOps pipeline samples
Decorator examples under [pipelines/decorators](pipelines/decorators) demonstrate injecting tasks (Hello World,
Gitleaks, Microsoft Security DevOps) via vss-extension.json plus YAML snippets. Token replacement pipeline sample in
[pipelines/replaceConfigurationFilesTokens](pipelines/replaceConfigurationFilesTokens/readme.md).
