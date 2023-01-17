#Requires -PSEdition Core
#Requires -Modules Az.Accounts

<#
    .SYNOPSIS
    This script connects to an Azure tenant using an application identity (App registration) and sets the context to the concernign App Registration

    .DESCRIPTION
    This script checks if there is a context already present with the provided app identity if so
    the context is set to that specific identity, if not a new connection is made using the supplied app identity.
    In the case of an existing context is found, that specific context is hen set to active, istaed of reconnectiing again.
    This is particularly useful for development purposses when using multiple identities is required.

    Limitation: multitenant identities are currently not supported

    .PARAMETER TenantId
    This is the tenant id to which the App Registration belongs

    .PARAMETER ClientId
    Application or the Client Id of the App Registration in question

    .PARAMETER ClientSecret
    A secret string that the App registration uses to prove its identity when requesting a token. Also can be referred to as application password.

    .EXAMPLE
    $authArgs = @{
        ApplicationId           = "1ef5b0b1-ecd2-4a54-bf2c-ae54ab32dfdf"
        ApplicationSecret       = 'Iru8Q~srAAAQtLLbSBsYuWGKpcVwUT35cPBdIdpI'
        TenantId                = "633e9d70-5551-400b-902a-baf94940f6ec"
    }
    Connect-AzInAppRegistrationContext @authArgs

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function Connect-AzInAppRegistrationContext {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ApplicationId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ApplicationSecret,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $TenantId
    )

    # get all alavailable az contexts and verify if one exists for current Aapp Registration
    $myContextCollection = Get-AzContext -ListAvailable
    $contextExists = $myContextCollection.Account | Where-Object { $_.Id -eq $ApplicationId -and $_.Type -eq 'ServicePrincipal' }

    # verify that all contexts originate from the same tenant
    $uniqueTenantsCount = $contextExists.Tenants | Group-Object -NoElement
    if ($null -ne $contextExists -and $uniqueTenantsCount.Values.Count -ne 1) {
        Write-Error -Message "Multiple tenants detected, please ensure the App Registration is not a multitenant one" -ErrorAction Stop
    }

    if ($null -eq $contextExists) {
        $secureSecret = ConvertTo-SecureString $ApplicationSecret -AsPlainText -Force
        $appCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationId, $secureSecret
        Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Credential $appCredential
    } else {
        Write-Information -MessageData "A context for the concerning App Registration is already active"

        if ($contextExists.ExtendedProperties.Keys.Contains("Subscriptions")) {
            Write-Information -MessageData "Setting current context to"
            $firstSubscription = $contextExists.ExtendedProperties.Subscriptions.split(',')[0]
            Set-AzContext -SubscriptionId $firstSubscription
        } else {
            Write-Information -MessageData "Current app registration does not have any resource permissions, skipping this context"
        }
    }
}
