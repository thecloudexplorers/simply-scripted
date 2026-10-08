using '../tenantPolicies.bicep'

// Fails: AssignmentEnforcementMode only accepts Default or DoNotEnforce
param policyAssignments = [
  {
    TargetScope: 'mg-platform'
    Assignment: {
      AssignmentName: 'audit-custom-roles'
      AssignmentDisplayName: 'Audit usage of custom RBAC roles'
      AssignmentDescription: 'Audits custom RBAC roles in favor of built-in roles'
      AssignmentEnforcementMode: 'Enforce'
      AssignmentNonComplianceMessage: 'Use built-in RBAC roles instead of custom roles'
      AssignmentPolicyId: '/providers/Microsoft.Authorization/policyDefinitions/a451c1ef-c6ca-483d-87ed-f49761e3ffb5'
    }
  }
]
