#Requires -PSEdition Core
<#
    .SYNOPSIS
    This function returns a well formatted Azure DevOps authentication token.

    .DESCRIPTION
    This function formats a user generated Azure DevOps PAT token and its
    creators name into a well authentication token which can be directly used
    in a rest call header.

    .PARAMETER PatToken
    Your PAT token as generated in Azure DevOps

    .PARAMETER PatTokenOwnerName
    Your name e.g. John Doe

    .EXAMPLE
    $adoAuthArgs = @{
    PatToken = "YOUR_PAT_TOKEN"
    PatTokenOwnerName = "John Doe"
    }

    $newToken = New-AdoAuthenticationToken @adoAuthArgs
    $header = @{authorization = "Basic $newToken"}

    .NOTES
    Version : 2.0.0
    Author  : Jev - @devjevnl | https://www.devjev.nl
    Source  : https://github.com/thecloudexplorers/simply-scripted
#>

function New-AdoAuthenticationToken {
    [CmdLetBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $PatToken,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $PatTokenOwnerName
    )

    # Format an authentication token
    Write-Debug -Message "Adding PatTokenOwnerName PatToken into a single string"
    $auth = " {0}:{1}" -f $PatTokenOwnerName, $PatToken

    Write-Debug -Message "Encoding the single string with ToBase64String"
    $utf8Auth = [System.Text.Encoding]::UTF8.GetBytes($Auth)
    $base64Auth = [System.Convert]::ToBase64String($utf8Auth)

    return $base64Auth
}
