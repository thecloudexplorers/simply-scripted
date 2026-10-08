using '../policyAssignment.bicep'

// Fails: AssignmentParamters is misspelled, it must not be ignored silently
param assignment = {
  AssignmentName: 'remediate-diag-settings'
  AssignmentDisplayName: 'DevJevnl Remediate diagnostic settings'
  AssignmentDescription: 'Remediates diagnostic settings'
  AssignmentEnforcementMode: 'Default'
  AssignmentNonComplianceMessage: 'Diagnostic settings must stream to the central Log Analytics workspace'
  AssignmentPolicyId: '/providers/Microsoft.Management/managementGroups/mg-platform/providers/Microsoft.Authorization/policySetDefinitions/devjevnl-remediate-diagnostic-settings'
  AssignmentIdentityType: 'SystemAssigned'
  AssignmentParamters: {}
}
