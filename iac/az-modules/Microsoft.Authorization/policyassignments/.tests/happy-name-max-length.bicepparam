using '../policyAssignment.bicep'

// Name of exactly 24 characters, the maximum at management group scope
param assignment = {
  AssignmentName: 'abcdefghijklmnopqrstuvwx'
  AssignmentDisplayName: 'Audit usage of custom RBAC roles'
  AssignmentDescription: 'Audits custom RBAC roles in favor of built-in roles'
  AssignmentEnforcementMode: 'Default'
  AssignmentNonComplianceMessage: 'Use built-in RBAC roles instead of custom roles'
  AssignmentPolicyId: '/providers/Microsoft.Authorization/policyDefinitions/a451c1ef-c6ca-483d-87ed-f49761e3ffb5'
  AssignmentIdentityType: 'None'
}
