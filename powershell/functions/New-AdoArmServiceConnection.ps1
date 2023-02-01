#Requires -PSEdition Core
<#
    .SYNOPSIS
    Creates a new service connection of the type Azure Resource Manager

    .DESCRIPTION
    This function creates an Azure Resource Manager in the specified project based on the specified App registration and a corresponding
    app secret. The secret hint is stored in the description field of the created service connection to allow matching of the secret
    for maintenance tasks

    .PARAMETER AdoApiUri
    Ado Api uri of Azure DevOps, unless modified by microsoft this should be https://dev.azure.com/

    .PARAMETER AdoOrganizationName
    Name of the concerning Azure DevOps organization

    .PARAMETER AdoProjectName
    Name of the concerning project

    .PARAMETER AdoProjectId
    Id of the concerning project

    .PARAMETER ServiceConnectionName
    Desired Service Connection name

    .PARAMETER TenantId
    Tenant Id of the concerning tenant for the desired service connection

    .PARAMETER SubscriptionId
    Subscription Id of the concerning tenant for the desired service connection

    .PARAMETER SubscriptionName
    Subscription name of the concerning tenant for the desired service connection

    .PARAMETER AppRegistrationId
    App id of the Az Ad Application that will be used for this service connection

    .PARAMETER AppRegistrationKey
    App secret of the Az Ad Application that will be used for this service connection

    .PARAMETER AppRegistrationKeyHint
    App secret hint of the Az Ad Application that will be used for this service connection, this hint will be stored in the description field to allow matching of the secret

    .PARAMETER AdoAuthenticationHeader
    Azure DevOps authentication header based on PAT token

    .EXAMPLE
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Basic ' + $authToken
    }

    $inputArgs = @{
        AdoVsspsApiUri = "https://vssps.dev.azure.com/"
        AdoOrganizationName = "my-organization"
        AdoProjectName = "My-AdoProject"
        AdoProjectId "070bc563-e9e9-4227-bee1-r045488791f4"
        ServiceConnectionName = "my-arm-service-connection"
        TenantId = "11e142dd-7e46-4ad8-8a0c-516940f8c402"
        SubscriptionId = "89c32bb9-6274-4293-aa91-68feb572489b"
        AppRegistrationKey = "vd9sxjnn5q4tht5uovaz77uidbyw"
        AppRegistrationKeyHint = "vd9"
        AdoAuthenticationHeader = $authHeader

    }

    New-AdoArmServiceConnection @inputArgs

    .NOTES
    Author: Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function New-AdoArmServiceConnection {
    [CmdLetBinding()]
    param (
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
        [System.String] $AdoProjectId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ServiceConnectionName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $TenantId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $SubscriptionId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $SubscriptionName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AppRegistrationId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AppRegistrationKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AppRegistrationKeyHint,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    Write-Information -MessageData " Creating new service connection"
    # each service connection id must be unique
    $serviceConnectionId = New-Guid
    $isReady = "false"

    $serviceConnectionObject = @{
        data                             = @{
            subscriptionId   = $SubscriptionId
            subscriptionName = $SubscriptionName
            environment      = "AzureCloud"
            scopeLevel       = "Subscription"
            creationMode     = "Manual"
        }
        url                              = "https://management.azure.com/"
        name                             = $ServiceConnectionName
        type                             = "AzureRM"
        authorization                    = @{
            parameters = @{
                tenantid            = $TenantId
                serviceprincipalid  = $AppRegistrationId
                authenticationType  = "spnKey"
                serviceprincipalkey = $AppRegistrationKey
            }
            scheme     = "ServicePrincipal"
        }
        isShared                         = $false
        isReady                          = $isReady
        serviceEndpointProjectReferences = @(@{
                projectReference = @{
                    id   = $AdoProjectId
                    name = $AdoProjectName
                }
                name             = $ServiceConnectionName
                description      = $AppRegistrationKeyHint
            })
        owner                            = "Library"
        description                      = $null
    }

    $serviceConnectionJsonObject = $serviceConnectionObject | ConvertTo-Json -Depth 5

    # https://docs.microsoft.com/en-us/rest/api/azure/devops/serviceendpoint/endpoints/create
    $serviceConnectionApiUri = $AdoApiUri + $AdoOrganizationName + "/_apis/serviceendpoint/endpoints/" + $serviceConnectionId + "?api-version=7.1-preview.4"
    $newServiceConnection = Invoke-RestMethod -Uri $serviceConnectionApiUri -Method 'Post' -Headers $AdoAuthenticationHeader -Body $serviceConnectionJsonObject

    # making sure background creation process has been completed for the new service connection
    Start-Sleep -Seconds 5

    Write-Information -MessageData " Service connection has been created"

    return $newServiceConnection
}
