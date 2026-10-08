# Tenant Policies Deployment

## Overview

Assigns Azure policies and initiatives to one or more management groups. Each entry in
`policyAssignments` becomes one policy assignment, deployed at the management group named in
`TargetScope`.

## Template

- Main template:
  [iac/az-controllers/tenantPolicies/tenantPolicies.bicep](iac/az-controllers/tenantPolicies/tenantPolicies.bicep)
- Child module:
  [iac/az-modules/Microsoft.Authorization/policyassignments/policyAssignment.bicep](iac/az-modules/Microsoft.Authorization/policyassignments/policyAssignment.bicep)
  ([documentation](iac/az-modules/Microsoft.Authorization/policyassignments/policyAssignment.md))
- Sample parameters:
  [iac/az-controllers/tenantPolicies/.tests](iac/az-controllers/tenantPolicies/.tests)

## Expected object shape

Each entry names the management group and holds the assignment. The `Assignment` type is imported from
the child module, see its documentation for the properties, validation rules, managed identity and role
assignment requirements.

```bicep
{
  TargetScope: 'mg-platform'                        // management group id
  Assignment: {
    AssignmentName: 'remediate-diag-settings'
    AssignmentDisplayName: 'Remediate diagnostic settings'
    AssignmentDescription: '...'
    AssignmentEnforcementMode: 'Default'
    AssignmentNonComplianceMessage: '...'
    AssignmentPolicyId: '/providers/Microsoft.Authorization/policySetDefinitions/...'
    AssignmentParameters: { ... }                   // optional
    AssignmentIdentityType: 'SystemAssigned'        // optional
    AssignmentLocation: 'westeurope'                // optional
  }
}
```

Both object types are sealed, so unknown or misspelled properties fail validation. The assignment
properties used to sit next to `TargetScope`, they must now be nested under `Assignment`.

## Test files

The [.tests](iac/az-controllers/tenantPolicies/.tests) folder contains parameter files that Bicep validates
offline. `happy-*` files must build, `unhappy-*` files must fail.

| File                                              | Expected                                                  |
| ------------------------------------------------- | --------------------------------------------------------- |
| `happy-minimal.bicepparam`                        | Builds, built-in audit policy                             |
| `happy-diagnostic-initiative.bicepparam`          | Builds, initiative with identity, location and parameters |
| `happy-multiple-scopes.bicepparam`                | Builds, same policy assigned to two management groups     |
| `happy-empty.bicepparam`                          | Builds, deploys nothing                                   |
| `unhappy-missing-required-property.bicepparam`    | Fails, `AssignmentPolicyId` is missing                    |
| `unhappy-missing-target-scope.bicepparam`         | Fails, `TargetScope` is missing                           |
| `unhappy-flat-shape.bicepparam`                   | Fails, assignment properties are not nested               |
| `unhappy-invalid-enforcement-mode.bicepparam`     | Fails, `Enforce` is not an allowed mode                   |
| `unhappy-invalid-identity-type.bicepparam`        | Fails, `UserAssigned` is not supported                    |
| `unhappy-name-too-long.bicepparam`                | Fails, `AssignmentName` is longer than 24 characters      |
| `unhappy-wrong-property-type.bicepparam`          | Fails, `AssignmentParameters` is an array                 |
| `unhappy-misspelled-optional-property.bicepparam` | Fails, `AssignmentParamters` is not a known property      |

```powershell
Get-ChildItem iac/az-controllers/tenantPolicies/.tests -Filter *.bicepparam |
    ForEach-Object { bicep build-params $_.FullName --stdout | Out-Null; "$($_.Name): exit $LASTEXITCODE" }
```

These checks only cover parameter shape. Role requirements and policy definition ids are validated at
deployment time.
