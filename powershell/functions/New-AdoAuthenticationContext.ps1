#Requires -PSEdition Core
<#
    .SYNOPSIS
    Authenticates against Microsoft Entra ID and returns a bearer access token
    scoped to Azure DevOps.

    .DESCRIPTION
    This script encapsulates all authentication logic for the Azure DevOps
    project vending pipeline. It supports two mutually exclusive authentication
    methods via parameter sets:

      ClientCredentials (default)
        Uses the OAuth 2.0 client credentials flow with an app registration
        ClientId and ClientSecret.

      AzContext
        Derives the token from an existing Az PowerShell context established
        via Connect-AzAccount. No credentials need to be supplied.

    The resulting bearer token can be passed to downstream scripts
    (e.g. azureDevOpsProjectVending.ps1 and azureDevOpsBootstrap.ps1) via
    their AdoAccessToken parameter.

    .PARAMETER TenantId
    (ClientCredentials) The Microsoft Entra ID tenant ID (GUID).

    .PARAMETER ClientId
    (ClientCredentials) The application (client) ID of the app registration.

    .PARAMETER ClientSecret
    (ClientCredentials) The client secret of the app registration as a
    SecureString.

    .PARAMETER UseAzContext
    (AzContext) Switch that instructs the script to acquire the Azure DevOps
    token from the current Az PowerShell context. Requires a prior
    Connect-AzAccount call.

    .OUTPUTS
    System.String
    Returns the Azure DevOps bearer access token string.

    .EXAMPLE
    # --- ClientCredentials ---
    $secret = ConvertTo-SecureString 'YOUR_CLIENT_SECRET' -AsPlainText -Force

    $authArgs = @{
        TenantId     = '00000000-0000-0000-0000-000000000000'
        ClientId     = '11111111-1111-1111-1111-111111111111'
        ClientSecret = $secret
    }
    $adoAccessToken = New-AdoAuthenticationContext @authArgs

    .EXAMPLE
    # --- AzContext ---
    Connect-AzAccount
    $adoAccessToken = New-AdoAuthenticationContext -UseAzContext

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    Regardless of the authentication method used, the identity must be added
    as a user in the target Azure DevOps organization via
    Organization Settings > Users. See:
    https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/service-principal-managed-identity
#>
[CmdLetBinding(DefaultParameterSetName = 'ClientCredentials')]
[OutputType([System.String])]
param (
    [Parameter(Mandatory, ParameterSetName = 'ClientCredentials')]
    [ValidateNotNullOrEmpty()]
    [System.String] $TenantId,

    [Parameter(Mandatory, ParameterSetName = 'ClientCredentials')]
    [ValidateNotNullOrEmpty()]
    [System.String] $ClientId,

    [Parameter(Mandatory, ParameterSetName = 'ClientCredentials')]
    [ValidateNotNullOrEmpty()]
    [System.Security.SecureString] $ClientSecret,

    [Parameter(Mandatory, ParameterSetName = 'AzContext')]
    [System.Management.Automation.SwitchParameter] $UseAzContext
)

$ErrorActionPreference = 'Stop'

# Azure DevOps resource / audience identifier.
# This well-known GUID is the application ID of the Azure DevOps service principal in Microsoft Entra ID.
# It is the same across all tenants and is used as the 'resource' (OAuth 2.0) or 'scope audience'
# (OAuth 2.0 v2 /.default) when requesting a token that grants access to Azure DevOps REST APIs.
$adoResourceId = '499b84ac-1321-427f-aa17-267ca6975798'

if ($PSCmdlet.ParameterSetName -eq 'AzContext') {

    Write-Debug 'Acquiring Azure DevOps access token from current Az context'

    $currentAzContext = Get-AzContext
    if ($null -eq $currentAzContext) {
        $errorMessage = 'No active Az context found. Run Connect-AzAccount before using -UseAzContext.'
        Write-Error -Message $errorMessage -ErrorAction Stop
    }

    Write-Debug "Using Az context identity [$($currentAzContext.Account.Id)]"

    $tokenObject = Get-AzAccessToken -ResourceUrl $adoResourceId -AsSecureString

    # SecureStringToBSTR allocates an unmanaged BSTR containing the plain-text token.
    # PtrToStringBSTR copies it into a managed string, then ZeroFreeBSTR overwrites
    # and releases the unmanaged buffer so the plain text is not left on the heap.
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenObject.Token)
    try {
        $adoAccessToken = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        # Zero out and release the unmanaged BSTR to prevent the token lingering in memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }

} else {

    Write-Debug "Acquiring Azure DevOps access token for client [$ClientId] in tenant [$TenantId]"

    $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    # Safely convert SecureString to plain text only for the HTTP body.
    # The BSTR is freed immediately after copying so the plain-text secret
    # exists in unmanaged memory for the shortest possible window.
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret)
    try {
        $plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        # Zero out and release the unmanaged BSTR to prevent the secret lingering in memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }

    $body = @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $plainSecret
        scope         = "$adoResourceId/.default"
    }

    $restMethodParams = @{
        Method      = 'POST'
        Uri         = $tokenEndpoint
        Body        = $body
        ContentType = 'application/x-www-form-urlencoded'
    }
    try {
        $response = Invoke-RestMethod @restMethodParams
    } finally {
        # Null out the plain-text secret from both variables regardless of whether
        # the request succeeded, so it is eligible for garbage collection immediately
        $plainSecret = $null
        $body['client_secret'] = $null
    }

    if ([System.String]::IsNullOrWhiteSpace($response.access_token)) {
        # Write-Error -ErrorAction Stop is preferred here over throw: this is a runtime failure
        # (unexpected response from the token endpoint) rather than a pre-condition violation.
        # It produces a structured ErrorRecord so callers can inspect $Error[0] with full context.
        $writeErrorParams = @{
            Message     = 'Token endpoint returned an empty access token. Verify the ClientId, ClientSecret, and TenantId.'
            Category    = 'InvalidResult'
            ErrorAction = 'Stop'
        }
        Write-Error @writeErrorParams
    }

    $adoAccessToken = $response.access_token
}

Write-Debug 'Azure DevOps access token successfully acquired'

# Emit ONLY the token to the output stream so callers capture a clean string
return $adoAccessToken
