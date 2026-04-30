# simply-scripted

This repo is a collection of automation snippets for Azure, Azure DevOps, and supporting tooling. The repo includes
Bicep controllers and modules, PowerShell deployment scripts and functions, and Azure DevOps pipeline decorator
examples.

## Prerequisites

- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- [Azure PowerShell module (`Az`)](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps)
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (optional, for some deployment scripts)

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

Sample parameter files live in [params](params):
- [params/bastionJumpBox.json](params/bastionJumpBox.json)
- [params/managementGroupsHierarchy.json](params/managementGroupsHierarchy.json)
- [params/serverVm.json](params/serverVm.json)
- [params/serviceGroupsHierarchy.json](params/serviceGroupsHierarchy.json)

## Bicep modules (building blocks)
Located under [iac/az-modules](iac/az-modules), organised by resource provider:
- **Microsoft.Management**:
  [childManagementGroup.bicep](iac/az-modules/Microsoft.Management/managementgroups/childManagementGroup.bicep),
  [childServiceGroup.bicep](iac/az-modules/Microsoft.Management/serviceGroups/childServiceGroup.bicep)
- **Microsoft.Network**:
  [smallNetwork.bicep](iac/az-modules/Microsoft.Network/virtualNetworks/smallNetwork.bicep),
  [standardSubnet.bicep](iac/az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep),
  [bastionNsg.bicep](iac/az-modules/Microsoft.Network/networkSecurityGroups/bastionNsg.bicep),
  [jumpVmNsg.bicep](iac/az-modules/Microsoft.Network/networkSecurityGroups/jumpVmNsg.bicep),
  [standardPip.bicep](iac/az-modules/Microsoft.Network/publicIPAddresses/standardPip.bicep),
  [simpleNic.bicep](iac/az-modules/Microsoft.Network/networkInterfaces/simpleNic.bicep),
  [basicBastionHost.bicep](iac/az-modules/Microsoft.Network/bastionHosts/basicBastionHost.bicep),
  [developerBastionHost.bicep](iac/az-modules/Microsoft.Network/bastionHosts/developerBastionHost.bicep)
- **Microsoft.Compute**:
  [jumpBoxVm.bicep](iac/az-modules/Microsoft.Compute/virtualMachines/jumpBoxVm.bicep),
  [serverVm.bicep](iac/az-modules/Microsoft.Compute/virtualMachines/serverVm.bicep)
- **Microsoft.KeyVault**:
  [standardVault.bicep](iac/az-modules/Microsoft.KeyVault/vaults/standardVault.bicep),
  [standardSecret.bicep](iac/az-modules/Microsoft.KeyVault/vaults/secrets/standardSecret.bicep)
- **Microsoft.ContainerRegistry**:
  [basicRegistry.bicep](iac/az-modules/Microsoft.ContainerRegistry/registries/basicRegistry.bicep)

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
- [Remove-AllEnIdAppRegistrations.ps1](powershell/functions/Remove-AllEnIdAppRegistrations.ps1)
- [Remove-AllEnIdGroups.ps1](powershell/functions/Remove-AllEnIdGroups.ps1)
- [Remove-AzRogueRoleAssignments.ps1](powershell/functions/Remove-AzRogueRoleAssignments.ps1)
- [Remove-ManagementGroupStructure.ps1](powershell/functions/Remove-ManagementGroupStructure.ps1)
- [Remove-SoftDeletedApiManagementInstance.ps1](powershell/functions/Remove-SoftDeletedApiManagementInstance.ps1)
- [Set-AdoAuditStream.ps1](powershell/functions/Set-AdoAuditStream.ps1)
- [Set-AzRoleAssignments.ps1](powershell/functions/Set-AzRoleAssignments.ps1)
- [Set-EnIdApps.ps1](powershell/functions/Set-EnIdApps.ps1)
- [Set-EnIdGroups.ps1](powershell/functions/Set-EnIdGroups.ps1)
- [Test-AdoServiceConnection.ps1](powershell/functions/Test-AdoServiceConnection.ps1)

## Azure DevOps pipeline samples
Decorator examples under [pipelines/decorators](pipelines/decorators) demonstrate injecting tasks via
`vss-extension.json` plus YAML snippets. Four examples are available:

- **powershell-hello-world-basic** — Injects a PowerShell "Hello World" task into every pipeline run.
- **powershell-hello-world-advanced** — Injects a PowerShell "Hello World" task after a Bash task.
- **microsoft-security-devops-basic** — Always injects the [Microsoft Security DevOps](https://learn.microsoft.com/en-us/azure/defender-for-cloud/azure-devops-extension) task into all pipelines.
- **microsoft-security-devops-advanced** — Injects the Microsoft Security DevOps task only when it is not already present in the pipeline.

Token replacement pipeline sample in
[pipelines/replaceConfigurationFilesTokens](pipelines/replaceConfigurationFilesTokens/readme.md).

## References
Historical and supplementary material in [references](references):
- [Read-AdoOrganizationAdvancedSecurityUsage.ps1](references/Read-AdoOrganizationAdvancedSecurityUsage.ps1) — Script for reading ADO Advanced Security usage data.
- [pre-defender-for-devops](references/pre-defender-for-devops) — Earlier Defender for DevOps pipeline decorator example (pre-`microsoft-security-devops` extension).
