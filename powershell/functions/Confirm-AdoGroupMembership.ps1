#Requires -PSEdition Core
<#
    .SYNOPSIS
    Verifies if an Azure AD group is already a group member

    .DESCRIPTION
    This script checks via in the input provided group object id if the concerning Azure AD Group is already a member
    of the via the Azure DevOps group descriptor provided Azure DevOps group

    .PARAMETER AdoOrganizationName
    Azure DevOps organization name

    .PARAMETER AdoTargetGroupDescriptor
    Descriptor property of the Azure DevOps group in which membership confirmation is needed

    .PARAMETER AzureADGroupId
    Group id of the Azure DevOps group who's membership needs confirmation

    .PARAMETER AdoAuthenticationHeader
    Azure DevOps authentication header based on PAT token

    .EXAMPLE
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Basic ' + $authToken
    }

    $inputArgs = @{
        AdoOrganizationName = "my-organization"
        AdoTargetGroupDescriptor = "vso.OWI3MYYyMTYtNGN0Zi03Yjc0LWE5MTEtZWZiMGZhOWM3Nzdm"
        AzureADGroupId "090bc563-e9e9-4227-beer-d04548879e3"
        AdoAuthenticationHeader = $authHeader
    }

    Confirm-AdoGroupMembership @inputArgs

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function Confirm-AdoGroupMembership {
    [OutputType([System.Boolean])]
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoOrganizationName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoTargetGroupDescriptor,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AzureADGroupId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )


    # get all members of the selected ADO project group
    # note: descriptors are returned, these will need to be resolved to real object like groups and users
    # note: direction=Down has been added to the query string, this is intentional as as 'down' will return all memberships
    # where the subject is a container (e.g. all members of the subject group).
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/graph/memberships/list
    # GET https://vssps.dev.azure.com/{organization}/_apis/graph/Memberships/{subjectDescriptor}?api-version=7.1-preview.1
    $membershipsApiUri = "https://vssps.dev.azure.com/" + $AdoOrganizationName + "/_apis/graph/Memberships/" + $AdoTargetGroupDescriptor + "?direction=Down&api-version=7.1-preview.1"
    $membershipsApiResponse = Invoke-RestMethod -Uri $membershipsApiUri  -Method 'Get' -Headers $AdoAuthenticationHeader

    $membershipsCollection = @{
        "lookupKeys" = @()
    }

    foreach ($groupMembership in $membershipsApiResponse.value.memberDescriptor) {
        $membershipObject = @{
            "descriptor" = $groupMembership
        }
        $membershipsCollection.lookupKeys += $membershipObject
    }

    $jsonMembershipCollection = $membershipsCollection | ConvertTo-Json -Depth 100

    # resolving descriptors to real subjects like users and groups
    # https://docs.microsoft.com/pt-pt/rest/api/azure/devops/graph/subject-lookup/lookup-subjects
    # POST https://vssps.dev.azure.com/{organization}/_apis/graph/subjectlookup?api-version=7.1-preview.1
    $subjectLookupApiUri = "https://vssps.dev.azure.com/" + $AdoOrganizationName + "/_apis/graph/subjectlookup?api-version=7.1-preview.1"
    $subjectLookupApiResponse = Invoke-RestMethod -Uri $subjectLookupApiUri  -Method 'Post' -Headers $AdoAuthenticationHeader -Body $jsonMembershipCollection

    $groupMembership = $subjectLookupApiResponse.value.PSObject.Properties | Where-Object { $_.Value.originId -eq $AzureADGroupId }

    if ($null -ne $groupMembership) {
        return $true
    } else {
        return $false
    }
}
