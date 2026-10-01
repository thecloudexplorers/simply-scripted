#Requires -PSEdition Core
<#
    .SYNOPSIS
    Creates a new Azure DevOps group at the Organization (collection) scope,
    or returns the existing group if one with the same display name is found.

    .DESCRIPTION
    This function creates a security group directly under the Azure DevOps
    organization scope using the Graph REST API. Groups created at this scope
    appear in Organization Settings > Permissions and can be used for
    organization-level permission assignments.

    If a group with the specified DisplayName already exists at the organization
    scope, the existing group object is returned without creating a duplicate.

    .PARAMETER AdoOrganizationName
    Name of the Azure DevOps organization (without the URL prefix).

    .PARAMETER GroupDisplayName
    Display name for the new organization-level group.

    .PARAMETER GroupDescription
    Optional description for the group.

    .PARAMETER AdoAuthenticationHeader
    Hashtable containing the Authorization (Bearer) and Content-Type headers
    used for all Azure DevOps REST API calls.

    .EXAMPLE
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + $accessToken
    }

    $groupArgs = @{
        AdoOrganizationName = 'my-organization'
        GroupDisplayName    = 'Project Creators'
        GroupDescription    = 'Members of this group can create new ADO projects'
        AdoAuthenticationHeader = $authHeader
    }
    $group = New-AdoOrganizationGroup @groupArgs

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    API reference:
    https://learn.microsoft.com/en-us/rest/api/azure/devops/graph/groups/create
#>
function New-AdoOrganizationGroup {
    [CmdLetBinding()]
    [OutputType([System.Object])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoOrganizationName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $GroupDisplayName,

        [Parameter()]
        [System.String] $GroupDescription,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    Write-Host "Retrieving organization scope descriptor for [$AdoOrganizationName]"

    # Step 1 – get the organization's instance ID from the connection data endpoint.
    # GET https://dev.azure.com/{org}/_apis/connectionData?api-version=7.2-preview.1
    $connectionDataUri = "https://dev.azure.com/$AdoOrganizationName/_apis/connectionData?api-version=7.2-preview.1"
    $connectionData = Invoke-RestMethod -Method 'GET' -Uri $connectionDataUri -Headers $AdoAuthenticationHeader
    $instanceId = $connectionData.instanceId

    # Step 2 – resolve the organization scope descriptor from the instance ID.
    # This descriptor is required to create groups at the org (collection) scope.
    # GET https://vssps.dev.azure.com/{org}/_apis/graph/descriptors/{storageKey}
    $descriptorUri = "https://vssps.dev.azure.com/$AdoOrganizationName/_apis/graph/descriptors/$($instanceId)?api-version=7.2-preview.1"
    $descriptorResponse = Invoke-RestMethod -Method 'GET' -Uri $descriptorUri -Headers $AdoAuthenticationHeader
    $orgScopeDescriptor = $descriptorResponse.value

    Write-Host "Organization scope descriptor: [$orgScopeDescriptor]"

    # Step 3 – check whether a group with this display name already exists at org scope.
    # GET https://vssps.dev.azure.com/{org}/_apis/graph/groups?scopeDescriptor={descriptor}
    $listGroupsUri = "https://vssps.dev.azure.com/$AdoOrganizationName/_apis/graph/groups?scopeDescriptor=$orgScopeDescriptor&api-version=7.2-preview.1"
    $existingGroupsResponse = Invoke-RestMethod -Method 'GET' -Uri $listGroupsUri -Headers $AdoAuthenticationHeader

    $existingGroup = $existingGroupsResponse.value | Where-Object { $_.displayName -eq $GroupDisplayName }
    if ($null -ne $existingGroup) {
        Write-Host "Organization group [$GroupDisplayName] already exists – skipping creation"
        return $existingGroup
    }

    # Step 4 – create the group at the organization scope.
    # POST https://vssps.dev.azure.com/{org}/_apis/graph/groups?scopeDescriptor={descriptor}
    Write-Host "Creating organization group [$GroupDisplayName]"
    $createGroupUri = "https://vssps.dev.azure.com/$AdoOrganizationName/_apis/graph/groups?scopeDescriptor=$orgScopeDescriptor&api-version=7.2-preview.1"

    $groupBody = @{
        displayName = $GroupDisplayName
        description = $GroupDescription
    } | ConvertTo-Json -Depth 3

    $newGroup = Invoke-RestMethod -Method 'POST' -Uri $createGroupUri `
        -Headers $AdoAuthenticationHeader `
        -Body $groupBody

    Write-Host "Organization group [$GroupDisplayName] created with descriptor [$($newGroup.descriptor)]"
    return $newGroup
}
