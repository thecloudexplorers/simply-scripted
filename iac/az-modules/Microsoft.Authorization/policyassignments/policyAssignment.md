# Policy Assignment Module

## Overview

Assigns a policy or initiative definition at the management group the module is deployed to. It is called
by [tenantPolicies.bicep](../../../az-controllers/tenantPolicies/tenantPolicies.bicep), which imports the
exported `policyAssignmentType` from this module so the validation rules exist in one place.

## Parameters

The module takes one parameter, `assignment`, of type `policyAssignmentType`. The type is sealed, so unknown
or misspelled properties fail validation.

| Property                         | Required | Notes                                                                   |
| -------------------------------- | -------- | ----------------------------------------------------------------------- |
| `AssignmentName`                 | Yes      | 1-24 characters, the limit at management group scope.                   |
| `AssignmentDisplayName`          | Yes      | 1-128 characters.                                                       |
| `AssignmentDescription`          | Yes      |                                                                         |
| `AssignmentEnforcementMode`      | Yes      | `Default` or `DoNotEnforce`.                                            |
| `AssignmentNonComplianceMessage` | Yes      | Applies to every policy in an initiative.                               |
| `AssignmentPolicyId`             | Yes      | Resource id of a policy definition or initiative.                       |
| `AssignmentParameters`           | No       | `{ parameterName: { value: parameterValue } }`, defaults to `{}`.       |
| `AssignmentIdentityType`         | No       | `None` (default) or `SystemAssigned`.                                   |
| `AssignmentLocation`             | No       | Only used with a managed identity, defaults to the deployment location. |

## Outputs

| Output                  | Notes                                                     |
| ----------------------- | --------------------------------------------------------- |
| `assignmentId`          | Resource id of the policy assignment.                     |
| `assignmentPrincipalId` | Principal id of the system assigned identity, else empty. |

## Managed identity and role assignments

Policies with the `DeployIfNotExists` or `Modify` effect need `AssignmentIdentityType: 'SystemAssigned'`.
The identity has no permissions after the assignment is created, so remediation fails until it is granted
roles. The diagnostic settings policies need:

| Role                      | Role definition id                     |
| ------------------------- | -------------------------------------- |
| Monitoring Contributor    | `749f88d5-cbae-40b8-bcfc-e573ddc772fa` |
| Log Analytics Contributor | `92aaf0da-9dab-42b6-94a3-d43ce8d16293` |

The role assignment is not part of this module. A role assignment module can use `assignmentPrincipalId`
as the principal.

## Not exposed

The module does not expose `notScopes`, `definitionVersion` or `overrides`.

## Test files

The [.tests](.tests) folder contains parameter files that Bicep validates offline. `happy-*` files must
build, `unhappy-*` files must fail.

| File                                           | Expected                                                  |
| ---------------------------------------------- | --------------------------------------------------------- |
| `happy-minimal.bicepparam`                     | Builds, required properties only                          |
| `happy-initiative-with-identity.bicepparam`    | Builds, initiative with identity, location and parameters |
| `happy-name-max-length.bicepparam`             | Builds, `AssignmentName` of exactly 24 characters         |
| `unhappy-missing-required-property.bicepparam` | Fails, `AssignmentPolicyId` is missing                    |
| `unhappy-invalid-enforcement-mode.bicepparam`  | Fails, `Enforce` is not an allowed mode                   |
| `unhappy-invalid-identity-type.bicepparam`     | Fails, `UserAssigned` is not supported                    |
| `unhappy-name-too-long.bicepparam`             | Fails, `AssignmentName` is 25 characters                  |
| `unhappy-empty-name.bicepparam`                | Fails, `AssignmentName` is empty                          |
| `unhappy-wrong-property-type.bicepparam`       | Fails, `AssignmentParameters` is an array                 |
| `unhappy-unknown-property.bicepparam`          | Fails, `AssignmentParamters` is not a known property      |

```powershell
Get-ChildItem iac/az-modules/Microsoft.Authorization/policyassignments/.tests -Filter *.bicepparam |
    ForEach-Object { bicep build-params $_.FullName --stdout | Out-Null; "$($_.Name): exit $LASTEXITCODE" }
```

These checks only cover parameter shape. Role requirements and policy definition ids are validated at
deployment time.
