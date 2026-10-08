using '../tenantPolicies.bicep'

// Initiative with DeployIfNotExists policies, needs a managed identity and the workspace resource ID
param policyAssignments = [
  {
    TargetScope: 'mg-platform'
    Assignment: {
      AssignmentName: 'remediate-diag-settings'
      AssignmentDisplayName: 'DevJevnl Remediate diagnostic settings'
      AssignmentDescription: 'Remediates diagnostic settings so the correct Log Analytics workspace receives audit logging'
      AssignmentEnforcementMode: 'Default'
      AssignmentNonComplianceMessage: 'Diagnostic settings must stream to the central Log Analytics workspace'
      AssignmentPolicyId: '/providers/Microsoft.Management/managementGroups/mg-platform/providers/Microsoft.Authorization/policySetDefinitions/devjevnl-remediate-diagnostic-settings'
      AssignmentIdentityType: 'SystemAssigned'
      AssignmentLocation: 'westeurope'
      AssignmentParameters: {
        logAnalytics: {
          value: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-platform'
        }
        logsEnabled: {
          value: true
        }
        metricsEnabled: {
          value: false
        }
      }
    }
  }
]
