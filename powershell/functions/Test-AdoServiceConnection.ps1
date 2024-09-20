#Requires -PSEdition Core
<#
    .SYNOPSIS
    Test an Azure DevOps service connection of the type Azure Resource
    Management

    .DESCRIPTION
    This function tests an Azure Resource Management type service connection.
    This is the same functionality
    as available via the verify button in the user interface.

    .PARAMETER AdoOrganizationName
    Name of the concerning Azure DevOps organization

    .PARAMETER AdoProjectName
    Name of the concerning project

    .PARAMETER ServiceConnectionObject
    Full service connection object, returned via get or new service connection
    function

    .PARAMETER AdoAuthenticationHeader
    Azure DevOps authentication header based on a PAT token


    .EXAMPLE
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Basic ' + $authToken
    }

    $inputArgs = @{
        AdoOrganizationName = "my-organization"
        AdoProjectName = "My-AdoProject"
        ServiceConnectionObject = $scObject
        AdoAuthenticationHeader = $authHeader
    }

    Test-AdoServiceConnection @inputArgs

    .NOTES
    Version : 2.0.0
    Author  : Jev - @devjevnl | https://www.devjev.nl
    Source  : https://github.com/thecloudexplorers/simply-scripted
#>

function Test-AdoServiceConnection {
    [OutputType([System.Boolean])]
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoOrganizationName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoProjectName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $ServiceConnectionObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    # Definition of return value
    $testSucceeded = $false

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
        serviceEndpointDetails      = $ServiceConnectionObject
    }

    $serviceEndpointJsonObject = $serviceEndpointRequestObject | ConvertTo-Json -Depth 10
    try {
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/serviceendpoint/endpointproxy/execute%20service%20endpoint%20request
        # POST https://dev.azure.com/{organization}/{project}/_apis/serviceendpoint/endpointproxy?endpointId={endpointId}&api-version=7.2-preview.1
        $serviceConnectionApiUr = "https://dev.azure.com/" + $AdoOrganizationName + "/" + $AdoProjectName + "/_apis/serviceendpoint/endpointproxy?endpointId=" + $ServiceConnectionObject.Id + "&api-version=7.2-preview.1"
        $serviceConnectionApiResponse = Invoke-RestMethod -Uri $serviceConnectionApiUr -Method 'Post' -Headers $AdoAuthenticationHeader -Body $serviceEndpointJsonObject
    } catch {
        throw "$($_.Exception)"
    }

    # Check if the service connection test was successful
    if ($serviceConnectionApiResponse.statusCode -ne "ok") {
        $testSucceeded = $false
    } else {
        $testSucceeded = $true
    }

    return $testSucceeded
}
