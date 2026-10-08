using '../policyAssignment.bicep'

// Fails: AssignmentName is 25 characters, the limit at management group scope is 24
param assignment = {
  AssignmentName: 'abcdefghijklmnopqrstuvwxy'
  AssignmentDisplayName: 'Audit usage of custom RBAC roles'
  AssignmentDescription: 'Audits custom RBAC roles in favor of built-in roles'
  AssignmentEnforcementMode: 'DoNotEnforce'
  AssignmentNonComplianceMessage: 'Use built-in RBAC roles instead of custom roles'
  AssignmentPolicyId: '/providers/Microsoft.Authorization/policyDefinitions/a451c1ef-c6ca-483d-87ed-f49761e3ffb5'
}
