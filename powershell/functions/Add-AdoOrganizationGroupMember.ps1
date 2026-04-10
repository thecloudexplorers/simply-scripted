#Requires -PSEdition Core
<#
    .SYNOPSIS
    Adds an Entra ID service principal (app registration) to an Azure DevOps
    organization-level group.

    .DESCRIPTION
    This function registers an Entra ID service principal in Azure DevOps (if it
    is not already present) and adds it as a member of the specified group using
    the Azure DevOps Graph REST API.

    The ServicePrincipalObjectId must be the Object ID of the Enterprise
    Application (service principal) in Entra ID – NOT the Application (client)
    ID of the app registration. You can retrieve it from:

        (Get-AzADServicePrincipal -ApplicationId '<clientId>').Id

    or in the Entra ID portal under Enterprise Applications > your app >
    Overview > Object ID.

    .PARAMETER AdoOrganizationName
    Name of the Azure DevOps organization (without the URL prefix).

    .PARAMETER GroupDescriptor
    The subject descriptor of the organization-level group, as returned by
    the Graph API (e.g. from New-AdoOrganizationGroup).

    .PARAMETER ServicePrincipalObjectId
    The Object ID of the Enterprise Application (service principal) in
    Entra ID that should be added to the group.

    .PARAMETER AdoAuthenticationHeader
    Hashtable containing the Authorization (Bearer) and Content-Type headers
    used for all Azure DevOps REST API calls.

    .EXAMPLE
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + $accessToken
    }

    $memberArgs = @{
        AdoOrganizationName       = 'my-organization'
        GroupDescriptor           = $group.descriptor
        ServicePrincipalObjectId  = '22222222-2222-2222-2222-222222222222'
        AdoAuthenticationHeader   = $authHeader
    }
    Add-AdoOrganizationGroupMember @memberArgs

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    Requires the app registration to first be granted access to the Azure
    DevOps organization via Organization Settings > Users or via the
    service principal REST API endpoint documented at:
    https://learn.microsoft.com/en-us/rest/api/azure/devops/graph/service-principals/create
#>
function Add-AdoOrganizationGroupMember {
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
        [System.String] $ServicePrincipalObjectId,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    Write-Host "Adding service principal [$ServicePrincipalObjectId] to group [$GroupDescriptor]"

    # Step 1 – create (or materialise) the service principal in the ADO graph
    # and simultaneously add it to the target group in a single API call.
    # If the service principal already exists in ADO, a 409 Conflict is returned
    # which we catch to then add it to the group via the membership API.
    #
    # POST https://vssps.dev.azure.com/{org}/_apis/graph/serviceprincipals
    #      ?groupDescriptors={groupDescriptor}
    #      &api-version=7.2-preview.1
    $createSpUri = "https://vssps.dev.azure.com/$AdoOrganizationName/_apis/graph/serviceprincipals" +
    "?groupDescriptors=$GroupDescriptor&api-version=7.2-preview.1"

    $spBody = @{
        originId = $ServicePrincipalObjectId
    } | ConvertTo-Json -Depth 2

    $servicePrincipalDescriptor = $null

    try {
        $invokeSpParams = @{
            Method  = 'POST'
            Uri     = $createSpUri
            Headers = $AdoAuthenticationHeader
            Body    = $spBody
        }
        $spResponse = Invoke-RestMethod @invokeSpParams

        $servicePrincipalDescriptor = $spResponse.descriptor
        Write-Host "Service principal registered in ADO and added to group. Descriptor: [$servicePrincipalDescriptor]"
    } catch {
        # HTTP 409 = service principal already exists in the ADO graph.
        # Retrieve its existing descriptor and add it to the group separately.
        if ($_.Exception.Response.StatusCode.value__ -eq 409) {
            Write-Host "Service principal already exists in ADO graph – retrieving existing descriptor"

            # GET https://vssps.dev.azure.com/{org}/_apis/graph/serviceprincipals/{originId}
            $getSpUri = "https://vssps.dev.azure.com/$AdoOrganizationName/_apis/graph/serviceprincipals/$($ServicePrincipalObjectId)?api-version=7.2-preview.1"
            $existingSp = Invoke-RestMethod -Method 'GET' -Uri $getSpUri -Headers $AdoAuthenticationHeader
            $servicePrincipalDescriptor = $existingSp.descriptor
        } else {
            throw
        }
    }

    if ($null -eq $servicePrincipalDescriptor) {
        $errorMessage = "Failed to obtain a descriptor for service principal [$ServicePrincipalObjectId]."
        Write-Error -Message $errorMessage -ErrorAction Stop
    }

    # Step 2 – if the service principal was already in ADO (caught above), add
    # it to the group via the memberships API.
    # PUT https://vssps.dev.azure.com/{org}/_apis/graph/memberships/{subjectDescriptor}/{containerDescriptor}
    Write-Host "Ensuring service principal [$servicePrincipalDescriptor] is member of group [$GroupDescriptor]"
    $membershipUri = "https://vssps.dev.azure.com/$AdoOrganizationName/_apis/graph/memberships" +
    "/$servicePrincipalDescriptor/$GroupDescriptor?api-version=7.2-preview.1"

    try {
        Invoke-RestMethod -Method 'PUT' -Uri $membershipUri -Headers $AdoAuthenticationHeader | Out-Null
        Write-Host "Service principal successfully added to group [$GroupDescriptor]"
    } catch {
        # HTTP 409 = membership already exists, which is acceptable.
        if ($_.Exception.Response.StatusCode.value__ -eq 409) {
            Write-Host "Service principal is already a member of group [$GroupDescriptor] – skipping"
        } else {
            throw
        }
    }
}
