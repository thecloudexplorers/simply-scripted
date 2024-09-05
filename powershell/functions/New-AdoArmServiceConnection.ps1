#Requires -PSEdition Core
<#
    .SYNOPSIS
    Creates a new service connection of the type Azure Resource Manager

    .DESCRIPTION
    This function creates an Azure Resource Manager in the specified project
    based on the specified App registration and a corresponding app secret.
    The secret hint is stored in the description field of the created service
    connection to allow matching of the secret for maintenance tasks

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
    App id of the Entra ID Application that will be used for this service connection

    .PARAMETER AppRegistrationKey
    App secret of the Entra ID Application that will be used for this service connection

    .PARAMETER AppRegistrationKeyHint
    App secret hint of the Entra ID Application that will be used for this service connection,
    this hint will be stored in the description field to allow matching of the secret

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
        AdoProjectId "YOUR_ADO_PROJECT_ID"
        ServiceConnectionName = "my-arm-service-connection"
        TenantId = "YOUR_TENANT_ID"
        SubscriptionId = "YOUR_SUBSCRIPTION_ID"
        AppRegistrationKey = "YOUR_APP_REGISTRATION_KEY"
        AppRegistrationKeyHint = "vd9"
        AdoAuthenticationHeader = $authHeader

    }

    New-AdoArmServiceConnection @inputArgs

    .NOTES
    Version     : 2.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function New-AdoArmServiceConnection {
    [CmdLetBinding()]
    param (
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

    Write-Host " Creating new service connection"
    # Each service connection id must be unique
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

    # Create new service endpoint
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/serviceendpoint/endpoints/create
    # POST https://dev.azure.com/{organization}/_apis/serviceendpoint/endpoints?api-version=7.2-preview.4
    $serviceConnectionApiUri = "https://dev.azure.com/" + $AdoOrganizationName + "/_apis/serviceendpoint/endpoints/" + $serviceConnectionId + "?api-version=7.2-preview.4"
    $newServiceConnection = Invoke-RestMethod -Uri $serviceConnectionApiUri -Method 'Post' -Headers $AdoAuthenticationHeader -Body $serviceConnectionJsonObject

    # Making sure background creation process has been completed for the new service connection
    Start-Sleep -Seconds 5

    Write-Host " Service connection has been created"

    return $newServiceConnection
}
