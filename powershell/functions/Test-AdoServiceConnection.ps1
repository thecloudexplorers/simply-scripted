#Requires -PSEdition Core
<#
    .SYNOPSIS
    Test an Azure DevOps service connection of the type Azure Resource Management

    .DESCRIPTION
    This function tests an Azure Resource Management type service connection. This is the same functionality
    as avalable via the verify button in the user interface.

    .PARAMETER AdoApiUri
    Ado Api uri of Azure DevOps, unless modified by Microsoft this should be https://dev.azure.com/

    .PARAMETER AdoOrganizationName
    Name of the concerning Azure DevOps organization

    .PARAMETER AdoProjectName
    Name of the concerning project

    .PARAMETER ServiceConncetionObject
    Full service connection object, returned via get or new service connection function

    .PARAMETER AdoAuthenticationHeader
    Azure DevOps authentication header based on a PAT token


    .EXAMPLE
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Basic ' + $authToken
    }

    $inputArgs = @{
        AdoApiUri = "https://dev.azure.com/"
        AdoOrganizationName = "my-organization"
        AdoProjectName = "My-AdoProject"
        ServiceConncetionObject = $scObject
        AdoAuthenticationHeader = $authHeader
    }

    Test-AdoServiceConnection @inputArgs

    .NOTES
    Author: Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function Test-AdoServiceConnection {
    [OutputType([System.Boolean])]
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoApiUri,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoOrganizationName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoProjectName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $ServiceConncetionObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    $serviceEndpointRequestObject = @{
        dataSourceDetails           = @{
            dataSourceName         = "TestConnection"
            dataSourceUrl          = ""
            headers                = $null
            resourceUrl            = ""
            requestContent         = $null
            requestVerb            = $null
            parameters             = $null
            resultSelector         = ""
            initialContextTemplate = ""
        }
        resultTransformationDetails = @{
            callbackContextTemplate  = ""
            callbackRequiredTemplate = ""
            resultTemplate           = ""
        }
        serviceEndpointDetails      = $ServiceConncetionObject
    }

    $serviceEndpointJsonObject = $serviceEndpointRequestObject | ConvertTo-Json -Depth 10

    # https://docs.microsoft.com/en-us/rest/api/azure/devops/serviceendpoint/endpointproxy/execute%20service%20endpoint%20request
    # POST https://dev.azure.com/{organization}/{project}/_apis/serviceendpoint/endpointproxy?endpointId={endpointId}&api-version=6.1-preview.1
    $serviceConnectionApiUr = $AdoApiUri + $AdoOrganizationName + "/" + $AdoProjectName + "/_apis/serviceendpoint/endpointproxy?endpointId=" + $ServiceConncetionObject.Id + "&api-version=6.1-preview.1"
    try {
        $serviceConnectionApiResponse = Invoke-RestMethod -Uri $serviceConnectionApiUr -Method 'Post' -Headers $AdoAuthenticationHeader -Body $serviceEndpointJsonObject

    } catch {
        throw "$($_.Exception)"
    }

    if ($serviceConnectionApiResponse.statusCode -ne "ok") {
        return $false
    }

    return $true
}
