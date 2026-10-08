metadata resources = {
  version: '2.0.0'
  author: 'Jev Suchoi'
  source: 'https://github.com/thecloudexplorers/simply-scripted'
  description: 'This Bicep file deploys a platform level compliance setup using Azure Policy Assignments'
}
metadata resourceSets = {}

targetScope = 'managementGroup'

import { policyAssignmentType } from '../../az-modules/Microsoft.Authorization/policyassignments/policyAssignment.bicep'

@sealed()
@description('A policy assignment and the management group it is assigned to')
type policyAssignmentEntryType = {
  @minLength(1)
  @description('Id of the management group the policy or initiative is assigned to')
  TargetScope: string

  Assignment: policyAssignmentType
}

@description('A collection of Azure Policy Assignments')
param policyAssignments policyAssignmentEntryType[] = []

module platformPoliciesDeployment '../../az-modules/Microsoft.Authorization/policyassignments/policyAssignment.bicep' = [
  for entry in policyAssignments: {
    name: 'policyAssignment-${uniqueString(entry.TargetScope)}-${entry.Assignment.AssignmentName}'
    scope: managementGroup(entry.TargetScope)
    params: {
      assignment: entry.Assignment
    }
  }
]
