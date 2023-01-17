#Requires -PSEdition Core
<#
    .SYNOPSIS
    This function creates an authentication token for the Microsoft Graph API

    .DESCRIPTION
    This function uses an App Registration Client Secret authentication to generate an authentication token
    for the Microsoft Graph API. This token can be used as input for the Connect-MgGraph cmdlet

    .PARAMETER TenantId
    This is the tenant id to which the App Registration belongs

    .PARAMETER ClientId
    Application or the Client Id of the App Registration in question

    .PARAMETER ClientSecret
    A secret string that the App registration uses to prove its identity when requesting a token. Also can be referred to as application password.

    .EXAMPLE
    $authArgs = @{
        TenantId         = "2dbf2872-4234-4545-8c59-82b5e004b883"
        ClientId         = "c100ff67-6a2e-47b6-94e4-a223026db051"
        ClientSecret     = 'Ifu7Q~srHHHQtLLbSBsYuWGKpcVwUT35cPBdIdpI'
    }
    $graphToken = Get-MgGraphToken @authArgs
    Connect-MgGraph -AccessToken $graphToken
    $header = @{authorization = "Basic $graphToken"}

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function Get-MgGraphToken {
    [CmdLetBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.string] $TenantId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.string] $ClientId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.string] $ClientSecret
    )

    # set body
    $oauthTokenBody = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }

    $oauthTokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    $webRequestArgs = @{
        Uri         = $oauthTokenUri
        ContentType = "application/x-www-form-urlencoded"
        Method      = 'POST'
        Body        = $oauthTokenBody

    }

    # requesst an outh token
    $response = Invoke-RestMethod @webRequestArgs

    return $response.access_token
}
