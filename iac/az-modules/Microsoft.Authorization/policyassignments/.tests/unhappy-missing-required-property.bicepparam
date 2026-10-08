using '../policyAssignment.bicep'

// Fails: AssignmentPolicyId is required
param assignment = {
  AssignmentName: 'audit-custom-roles'
  AssignmentDisplayName: 'Audit usage of custom RBAC roles'
  AssignmentDescription: 'Audits custom RBAC roles in favor of built-in roles'
  AssignmentEnforcementMode: 'DoNotEnforce'
  AssignmentNonComplianceMessage: 'Use built-in RBAC roles instead of custom roles'
}
