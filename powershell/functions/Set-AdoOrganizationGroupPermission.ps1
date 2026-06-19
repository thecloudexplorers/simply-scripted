#Requires -PSEdition Core
<#
    .SYNOPSIS
    Grants a named permission to an Azure DevOps organization-level group by
    dynamically discovering the relevant security namespace.

    .DESCRIPTION
    This function sets an Allow Access Control Entry (ACE) for a given security
    permission on an ADO group at the organization (collection) scope.

    The security namespace that owns the target permission is discovered at
    runtime by querying all available namespaces and matching the action
    display name. The organization's instance ID (obtained from connectionData)
    is used to build the collection-scope security token.

    .PARAMETER AdoOrganizationName
    Name of the Azure DevOps organization (without the URL prefix).

    .PARAMETER GroupDescriptor
    The subject descriptor of the organization-level group, as returned by
    the Graph API (e.g. from New-AdoOrganizationGroup).

    .PARAMETER PermissionDisplayName
    The display name of the permission action to grant, exactly as it appears
    in the ADO security namespace definition. For creating projects use:
    'Create new projects'

    .PARAMETER AdoAuthenticationHeader
    Hashtable containing the Authorization (Bearer) and Content-Type headers
    used for all Azure DevOps REST API calls.

    .EXAMPLE
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + $accessToken
    }

    $permArgs = @{
        AdoOrganizationName     = 'my-organization'
        GroupDescriptor         = $group.descriptor
        PermissionDisplayName   = 'Create new projects'
        AdoAuthenticationHeader = $authHeader
    }
    Set-AdoOrganizationGroupPermission @permArgs

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    API references:
    https://learn.microsoft.com/en-us/rest/api/azure/devops/security/access-control-entries/set-access-control-entries
    https://learn.microsoft.com/en-us/rest/api/azure/devops/security/security-namespaces/query
#>
function Set-AdoOrganizationGroupPermission {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoOrganizationName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $GroupDescriptor,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $PermissionDisplayName,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    Write-Host "Resolving security namespace for permission [$PermissionDisplayName]"

    # Step 1 – retrieve all security namespaces and find the one that owns the
    # requested permission action.
    # GET https://dev.azure.com/{org}/_apis/securitynamespaces?api-version=7.2
    $namespacesUri = "https://dev.azure.com/$AdoOrganizationName/_apis/securitynamespaces?api-version=7.2"
    $namespacesResponse = Invoke-RestMethod -Method 'GET' -Uri $namespacesUri -Headers $AdoAuthenticationHeader

    $targetNamespaceId = $null
    $targetBit = 0

    foreach ($namespace in $namespacesResponse.value) {
        $matchingAction = $namespace.actions | Where-Object {
            $_.displayName -eq $PermissionDisplayName -or $_.name -eq $PermissionDisplayName
        }
        if ($null -ne $matchingAction) {
            $targetNamespaceId = $namespace.namespaceId
            $targetBit = $matchingAction.bit
            Write-Host "Found namespace [$($namespace.name)] (id: $targetNamespaceId) with action bit [$targetBit]"
            break
        }
    }

    if ($null -eq $targetNamespaceId) {
        $errorMessage = "Could not locate a security namespace containing the action [$PermissionDisplayName]. " +
        "Verify the PermissionDisplayName matches an action in the ADO security namespaces."
        Write-Error -Message $errorMessage -ErrorAction Stop
    }

    # Step 2 – resolve the group subject descriptor to an identity descriptor
    # that the Security REST API accepts in an ACE. The Identities API accepts
    # a subject descriptor and returns the full identity with its descriptor.
    # GET https://vssps.dev.azure.com/{org}/_apis/identities?subjectDescriptors={descriptor}
    Write-Host "Resolving identity descriptor for group [$GroupDescriptor]"
    $identityUri = "https://vssps.dev.azure.com/$AdoOrganizationName/_apis/identities?subjectDescriptors=$GroupDescriptor&api-version=7.2"
    $identityResponse = Invoke-RestMethod -Method 'GET' -Uri $identityUri -Headers $AdoAuthenticationHeader

    if ($null -eq $identityResponse.value -or $identityResponse.value.Count -eq 0) {
        $errorMessage = "Could not resolve an identity for group descriptor [$GroupDescriptor]. " +
        "Ensure the group exists in the Azure DevOps organization."
        Write-Error -Message $errorMessage -ErrorAction Stop
    }
    $groupIdentityDescriptor = $identityResponse.value[0].descriptor

    # Step 3 – get the organization instance ID to build the collection-scope
    # security token. For the 'Project' namespace (which owns 'Create new
    # projects'), the collection-scope token is the organization instance ID.
    $connectionDataUri = "https://dev.azure.com/$AdoOrganizationName/_apis/connectionData?api-version=7.2-preview.1"
    $connectionData = Invoke-RestMethod -Method 'GET' -Uri $connectionDataUri -Headers $AdoAuthenticationHeader
    $instanceId = $connectionData.instanceId

    # The security token for organization/collection-scope permissions in the
    # Project namespace uses the collection instance ID as the resource token.
    $securityToken = "`$PROJECT:vstfs:///Classification/TeamProject/$instanceId"

    # Step 4 – set the ACE to Allow the target permission bit on the group.
    # POST https://dev.azure.com/{org}/_apis/accesscontrolentries/{namespaceId}
    Write-Host "Granting permission [$PermissionDisplayName] (bit: $targetBit) to group [$GroupDescriptor]"
    $setAceUri = "https://dev.azure.com/$AdoOrganizationName/_apis/accesscontrolentries/$($targetNamespaceId)?api-version=7.2"

    $aceBody = @{
        token                = $securityToken
        merge                = $true
        accessControlEntries = @(
            @{
                descriptor = $groupIdentityDescriptor
                allow      = $targetBit
                deny       = 0
            }
        )
    } | ConvertTo-Json -Depth 4

    $invokeParams = @{
        Method  = 'POST'
        Uri     = $setAceUri
        Headers = $AdoAuthenticationHeader
        Body    = $aceBody
    }
    Invoke-RestMethod @invokeParams | Out-Null

    Write-Host "Permission [$PermissionDisplayName] successfully granted to group [$GroupDescriptor]"
}
