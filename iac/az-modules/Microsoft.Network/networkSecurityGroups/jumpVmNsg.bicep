metadata moduleMetadata = {
  version: '1.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: '''This module deploys an NSG with a rule to allow traffic from the Azure Bastion
  subnet to the VMs in the VNet.'''
}

@description('Name for the NSG resource resource')
param networkSecurityGroupName string = 'djn-s-dmo-nsg002'

@description('''Ip address prefix for the Azure Bastion subnet. This is used to restrict the NSG
to only allow traffic from the Azure Bastion subnet to the VMs in the VNet. This is a required
parameter and must be a valid IP address prefix in CIDR notation. Example:''')
param bastionSubnetAddressPrefix string = '10.0.1.0/25'

@description('Region in which the NSG should be deployed')
param location string = 'West Europe'

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSshRdpAzureBastionInbound'
        properties: {
          direction: 'Inbound'
          priority: 200
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          protocol: '*'
          sourceAddressPrefix: bastionSubnetAddressPrefix
          destinationAddressPrefix: '*'
          access: 'Allow'
        }
      }
    ]
  }
}

output nsgId string = networkSecurityGroup.id
