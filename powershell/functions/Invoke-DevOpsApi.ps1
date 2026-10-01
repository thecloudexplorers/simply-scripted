<#
    .SYNOPSIS
    Invokes an Azure DevOps REST API endpoint.

    .DESCRIPTION
    Wraps Invoke-RestMethod, passing the supplied headers (including the Authorization header)
    and serializing the optional body to JSON, to call Azure DevOps REST endpoints.

    .PARAMETER Uri
    The full request URI, including api-version.

    .PARAMETER Method
    The HTTP method to use. Defaults to GET. Mandatory together with -Body.

    .PARAMETER Body
    The request payload, serialized to JSON. When provided, -Method must be provided as well.

    .PARAMETER Headers
    The request headers, including the Authorization header.

    .EXAMPLE
    $invokeDevOpsApiParameters = @{
        Uri = 'https://dev.azure.com/org/proj/_apis/git/repositories/repo/refs?api-version=7.1'
        Headers = @{ Authorization = "Bearer $accessToken" }
    }
    Invoke-DevOpsApi @invokeDevOpsApiParameters

    Sends a GET request without a body.

    .EXAMPLE
    $invokeDevOpsApiParameters = @{
        Uri = 'https://dev.azure.com/org/proj/_apis/git/repositories/repo/commitsBatch?api-version=7.1'
        Method = 'POST'
        Body = @{ ids = @('<commit-id>') }
        Headers = @{ Authorization = "Bearer $accessToken" }
    }
    Invoke-DevOpsApi @invokeDevOpsApiParameters

    Sends a POST request with a JSON body.

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
function Invoke-DevOpsApi {
    # WithoutBody: Method is optional. WithBody: Method and Body must be supplied together.
    [CmdletBinding(DefaultParameterSetName = 'WithoutBody')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'WithoutBody')]
        [Parameter(Mandatory, ParameterSetName = 'WithBody')]
        [System.String] $Uri,

        [Parameter(ParameterSetName = 'WithoutBody')]
        [Parameter(Mandatory, ParameterSetName = 'WithBody')]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [System.String] $Method

        [Parameter(Mandatory, ParameterSetName = 'WithBody')]
        [System.Object] $Body,

        [Parameter(Mandatory, ParameterSetName = 'WithoutBody')]
        [Parameter(Mandatory, ParameterSetName = 'WithBody')]
        [System.Collections.Hashtable] $Headers
    )

    $invokeArguments = @{
        Uri         = $Uri
        Method      = $Method
        Headers     = $Headers
        ErrorAction = 'Stop'
    }
    if ($PSCmdlet.ParameterSetName -eq 'WithBody') {
        $invokeArguments.Body = ($Body | ConvertTo-Json -Depth 5)
        $invokeArguments.ContentType = 'application/json'
    }

    return Invoke-RestMethod @invokeArguments
}
