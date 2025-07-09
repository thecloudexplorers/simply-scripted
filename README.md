# simply-scripted

This repo is a collection of scripts, functions, controllers and lab configurations that support automation of Azure, Azure DevOps and related tooling.

## Lab Environments

### Jump Box Lab

This lab is demonstrates how to set-up secure access to a Server Virtual Machine using Azure Basting and a Jump Box Client Virtual Machine.

#### Included Bicep Controllers

The following controllers .bicep files are used to create the lab environment. Each combines the required Bicep modules to create the lab environment.

- iac\az-controllers\bastionJumpBox.bicep - A Bicep controller that by combining the present Bicep modules creates a Jump Box Virtual Machine and an Azure Bastion Host.
- iac\az-controllers\serverVM.bicep - A Bicep controller that by combining the present Bicep creates the required subnet and a Windows Server Virtual Machine.

#### Included Bicep Modules

- iac\az-modules\Microsoft.Network\networkSecurityGroups\bastionNsg.bicep - A Bicep module that creates a network security group for the Azure Bastion Host.
- iac\az-modules\Microsoft.Network\networkSecurityGroups\jumpVmNsg.bicep - A Bicep module that creates a network security group for the Jump Box Virtual Machine.
- iac\az-modules\Microsoft.Network\virtualNetworks\smallNetwork.bicep - A Bicep module that creates a small satellite virtual network.
- iac\az-modules\Microsoft.Network\virtualNetworks\subnets\standardSubnet.bicep - A Bicep module that creates a standard subnet.
- iac\az-modules\Microsoft.Network\publicIPAddresses\standardPip.bicep - A Bicep module that creates a standard public IP address.
- iac\az-modules\Microsoft.Network\bastionHosts\basicBastionHost.bicep - A Bicep module that creates a basic Azure Bastion Host.
- iac\az-modules\Microsoft.Network\networkInterfaces\simpleNic.bicep - A Bicep module that creates a simple network interface.
- iac\az-modules\Microsoft.Compute\virtualMachines\jumpBoxVm.bicep - A Bicep module that creates a windows 10 jump box virtual machine.
- iac\az-modules\Microsoft.KeyVault\vaults\standardVault.bicep - A Bicep module that creates a Key Vault.
- iac\az-modules\Microsoft.KeyVault\vaults\secrets\standardSecret.bicep - A Bicep module that creates a Key Vault and a secret.
- iac\az-modules\Microsoft.Compute\virtualMachines\serverVm.bicep - A Bicep module that creates a Windows Server Virtual Machine.

### Scripts

- powershell\deployBastionJumpBox.ps1 - A PowerShell script that deploys the Jump Box Lab environment using the Bicep controller.
- powershell\deployServerVm.ps1 - A PowerShell script that deploys the Server Virtual Machine using the Bicep controller.

## PowerShell Functions

This repo provides the following PowerShell functions:

- Add-AzAdApplicationOwnerInBulk
- Confirm-AdoGroupMembership
- Connect-AzInAppRegistrationContext
- Connect-MgGraphWithCurrentAzContext
- Convert-AdoYamlToJson
- Get-FileHashDownload
- Get-MgGraphToken

## Bicep Modules

This repo provides the following Bicep modules:

- jumpBoxVm
- serverVm
- basicRegistry
- basicRegistry
- standardSecret
- basicBastionHost
- simpleNic
- bastionNsg
- jumpVmNsg
- standardPip
- standardSubnet
- smallNetwork
