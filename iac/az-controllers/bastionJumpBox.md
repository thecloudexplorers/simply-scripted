# Bastion JumpBox QuickStart Pattern

## Description

This Bicep QuickStart pattern deploys a virtual network with two subnets, a bastion host, a jumpbox virtual machine (VM),
and a key vault. Additionally, it creates a secret in the key vault for the jumpbox VM's username and
password. The jumpbox VM is deployed with the specified username and password, and the key vault is
granted full data plane access to the specified user or service principal. The purpose of this lab is
to provide a secure environment where the jumpbox VM acts as a gateway for accessing other resources
within the virtual network through the bastion host, ensuring secure and efficient management.

## Bicep Modules

The lab consists of the following Bicep modules:

1. Bastion Network Security Group (NSG)
   - File: `../az-modules/Microsoft.Network/networkSecurityGroups/bastionNsg.bicep`
   - Purpose: Deploys the NSG for the bastion host.

2. JumpBox VM Network Security Group (NSG)
   - File: `../az-modules/Microsoft.Network/networkSecurityGroups/jumpVmNsg.bicep`
   - Purpose: Deploys the NSG for the jumpbox VM.

3. Small Virtual Network
   - File: `../az-modules/Microsoft.Network/virtualNetworks/smallNetwork.bicep`
   - Purpose: Deploys the virtual network with specified address prefixes.

4. Bastion Subnet
   - File: `../az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep`
   - Purpose: Deploys the subnet for the bastion host.

5. JumpBox VM Subnet
   - File: `../az-modules/Microsoft.Network/virtualNetworks/subnets/standardSubnet.bicep`
   - Purpose: Deploys the subnet for the jumpbox VM.

6. Public IP Address for Bastion Host
   - File: `../az-modules/Microsoft.Network/publicIPAddresses/standardPip.bicep`
   - Purpose: Deploys a standard public IP address for the bastion host.

7. Bastion Host
   - File: `../az-modules/Microsoft.Network/bastionHosts/basicBastionHost.bicep`
   - Purpose: Deploys the bastion host.

8. Network Interface Card (NIC) for JumpBox VM
   - File: `../az-modules/Microsoft.Network/networkInterfaces/simpleNic.bicep`
   - Purpose: Deploys the NIC for the jumpbox VM.

9. JumpBox VM
   - File: `../az-modules/Microsoft.Compute/virtualMachines/jumpBoxVm.bicep`
   - Purpose: Deploys the jumpbox VM with the specified size and credentials.

10. Key Vault
    - File: `../az-modules/Microsoft.KeyVault/vaults/standardVault.bicep`
    - Purpose: Deploys the key vault and grants access to the specified user or service principal.

11. Key Vault Secret for Username
    - File: `../az-modules/Microsoft.KeyVault/vaults/secrets/standardSecret.bicep`
    - Purpose: Creates a secret in the key vault for the jumpbox VM's username.

12. Key Vault Secret for Password
    - File: `../az-modules/Microsoft.KeyVault/vaults/secrets/standardSecret.bicep`
    - Purpose: Creates a secret in the key vault for the jumpbox VM's password.

## PowerShell Scripts

The lab setup includes the following PowerShell scripts:

1. deployBastionJumpBox.ps1
   - File: `powershell/deployBastionJumpBox.ps1`
   - Purpose: Deploy Bastion JumpBox VM, Deploy the Server VM and Install IIS on the Server VM
