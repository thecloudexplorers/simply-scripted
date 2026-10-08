using '../tenantPolicies.bicep'

// The same policy assigned to two management groups, one enforced and one in audit only mode
param policyAssignments = [
  {
    TargetScope: 'mg-platform'
    Assignment: {
      AssignmentName: 'audit-custom-roles'
      AssignmentDisplayName: 'Audit usage of custom RBAC roles (platform)'
      AssignmentDescription: 'Audits custom RBAC roles on the platform management group'
      AssignmentEnforcementMode: 'Default'
      AssignmentNonComplianceMessage: 'Use built-in RBAC roles instead of custom roles'
      AssignmentPolicyId: '/providers/Microsoft.Authorization/policyDefinitions/a451c1ef-c6ca-483d-87ed-f49761e3ffb5'
      AssignmentIdentityType: 'None'
    }
  }
  {
    TargetScope: 'mg-landingzones'
    Assignment: {
      AssignmentName: 'audit-custom-roles'
      AssignmentDisplayName: 'Audit usage of custom RBAC roles (landing zones)'
      AssignmentDescription: 'Audits custom RBAC roles on the landing zones management group'
      AssignmentEnforcementMode: 'DoNotEnforce'
      AssignmentNonComplianceMessage: 'Use built-in RBAC roles instead of custom roles'
      AssignmentPolicyId: '/providers/Microsoft.Authorization/policyDefinitions/a451c1ef-c6ca-483d-87ed-f49761e3ffb5'
    }
  }
]
