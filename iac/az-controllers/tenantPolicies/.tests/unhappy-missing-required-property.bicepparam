using '../tenantPolicies.bicep'

// Fails: Assignment.AssignmentPolicyId is missing
param policyAssignments = [
  {
    TargetScope: 'mg-platform'
    Assignment: {
      AssignmentName: 'audit-custom-roles'
      AssignmentDisplayName: 'Audit usage of custom RBAC roles'
      AssignmentDescription: 'Audits custom RBAC roles in favor of built-in roles'
      AssignmentEnforcementMode: 'DoNotEnforce'
      AssignmentNonComplianceMessage: 'Use built-in RBAC roles instead of custom roles'
    }
  }
]
