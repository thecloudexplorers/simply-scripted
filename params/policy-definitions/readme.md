# Policy definitions

Azure Policy definitions and initiatives (policy sets) used by this repository.

## Initiatives

### 001.remediate-diagnostic-settings

Deploys diagnostic settings to a Log Analytics workspace for Storage (blob, file, queue, table), Key Vault and Virtual Network, using built-in policies.

| Reference ID      | Built-in policy                                                                                            |
| ----------------- | ---------------------------------------------------------------------------------------------------------- |
| `storage-blob`    | Configure diagnostic settings for Blob Services to Log Analytics workspace                                 |
| `storage-file`    | Configure diagnostic settings for File Services to Log Analytics workspace                                 |
| `storage-queue`   | Configure diagnostic settings for Queue Services to Log Analytics workspace                                |
| `storage-table`   | Configure diagnostic settings for Table Services to Log Analytics workspace                                |
| `key-vault`       | Deploy - Configure diagnostic settings for Azure Key Vault to Log Analytics workspace                      |
| `virtual-network` | Enable logging by category group for Virtual networks (microsoft.network/virtualnetworks) to Log Analytics |

Notes:

- `logAnalytics` has no default. Pass the full resource ID of the workspace when assigning the initiative.
- The `virtual-network` policy always uses the `allLogs` category group, so `logsEnabled` does not apply to it.

## Remediation of existing resources

`DeployIfNotExists` policies only act on resources that are created or updated after the assignment. Existing resources need a remediation task.

The Queue and Table policies are additionally not triggered when a Storage Account is created, so they require a remediation task for every account, including new ones. Create one remediation task per policy in the initiative, for example:

```powershell
$assignment = Get-AzPolicyAssignment -Name "<assignment-name>" -Scope "<scope>"

Start-AzPolicyRemediation `
    -Name "remediate-storage-queue" `
    -PolicyAssignmentId $assignment.Id `
    -PolicyDefinitionReferenceId "storage-queue" `
    -Scope "<scope>"
```

Repeat with `-PolicyDefinitionReferenceId "storage-table"` for Table Services.

Renaming a `policyDefinitionReferenceId` breaks remediation tasks that still use the old value, so recreate them after changing a reference ID.
