using '../tenantPolicies.bicep'

// Fails: the old flat shape, the assignment properties must be nested under Assignment
param policyAssignments = [
  {
    TargetScope: 'mg-platform'
    AssignmentName: 'audit-custom-roles'
    AssignmentDisplayName: 'Audit usage of custom RBAC roles'
    AssignmentDescription: 'Audits custom RBAC roles in favor of built-in roles'
    AssignmentEnforcementMode: 'DoNotEnforce'
    AssignmentNonComplianceMessage: 'Use built-in RBAC roles instead of custom roles'
    AssignmentPolicyId: '/providers/Microsoft.Authorization/policyDefinitions/a451c1ef-c6ca-483d-87ed-f49761e3ffb5'
  }
]
