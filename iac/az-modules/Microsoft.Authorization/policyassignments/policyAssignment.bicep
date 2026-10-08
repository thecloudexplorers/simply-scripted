metadata moduleMetadata = {
  version: '2.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: 'This bicep file assigns a policy or initiative definition to the management group it is deployed to'
}

targetScope = 'managementGroup'

@export()
@sealed()
@description('An Azure Policy Assignment')
type policyAssignmentType = {
  @minLength(1)
  @maxLength(24)
  @description('Policy assignment name, 24 characters is the limit at management group scope')
  AssignmentName: string

  @minLength(1)
  @maxLength(128)
  @description('Display name of the Policy Assignment')
  AssignmentDisplayName: string

  @description('Description for the Azure Policy Assignment')
  AssignmentDescription: string

  @description('Assignment enforcement mode, choose between Default or DoNotEnforce')
  AssignmentEnforcementMode: 'Default' | 'DoNotEnforce'

  @description('Custom message that describes why a resource is non-compliant with the policy or initiative definition')
  AssignmentNonComplianceMessage: string

  @minLength(1)
  @description('The full path name of either a policy definition or an initiative definition')
  AssignmentPolicyId: string

  @description('Parameter values for the assigned policy or initiative, in the form { parameterName: { value: parameterValue } }, defaults to none')
  AssignmentParameters: object?

  @description('Managed identity type, SystemAssigned is required for policies with the DeployIfNotExists or Modify effect, defaults to None')
  AssignmentIdentityType: ('None' | 'SystemAssigned')?

  @description('Location of the policy assignment, only used with a managed identity, defaults to the deployment location')
  AssignmentLocation: string?
}

@description('The policy assignment to create')
param assignment policyAssignmentType

var identityType = assignment.?AssignmentIdentityType ?? 'None'

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2025-03-01' = {
  name: assignment.AssignmentName
  location: assignment.?AssignmentLocation ?? deployment().location
  identity: {
    type: identityType
  }
  properties: {
    displayName: assignment.AssignmentDisplayName
    description: assignment.AssignmentDescription
    enforcementMode: assignment.AssignmentEnforcementMode
    nonComplianceMessages: [
      {
        message: assignment.AssignmentNonComplianceMessage
      }
    ]
    policyDefinitionId: assignment.AssignmentPolicyId
    parameters: assignment.?AssignmentParameters ?? {}
  }
}

@description('Resource Id of the policy assignment')
output assignmentId string = policyAssignment.id

@description('Principal Id of the system assigned identity, empty when no identity is assigned')
output assignmentPrincipalId string = identityType == 'SystemAssigned' ? policyAssignment.identity.principalId : ''
