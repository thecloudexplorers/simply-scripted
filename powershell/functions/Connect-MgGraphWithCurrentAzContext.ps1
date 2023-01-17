#Requires -PSEdition Core
#Requires -Modules Az.Accounts
#Requires -Modules Microsoft.Graph.Authentication

<#
    .SYNOPSIS
    This function connects to MgGraph (Connect-MgGraph) by acquiring the token from the current AzContext (Get-AzAccessToken)

    .DESCRIPTION
    This function uses the current AzContext bearer token to connect to MgGraph. If an existing MgGraph context exists,
    the function checks if this context matches the current AzContext. If this is not the case
    Disconnect-MgGraph is used followed by a reconnect with the current AzContext token

    .EXAMPLE
    Connect-MgGrapWithCurrentAzContext

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function Connect-MgGrapWithCurrentAzContext {
    try {
        Write-Information -MessageData "`nEnsuring proper connection `nChecking AzContext..."
        $currentAzContext = Get-AzContext
        if ($null -ne $currentAzContext ) {
            # use the current az context. graphToken is using in header building and should be a string
            Write-Information -MessageData "An active azure context was found. Using the current context for MgGraph authorization"

            $currentMgContext = Get-MgContext
            Write-Information -MessageData "Verifying MgContext ClientId with AzContext AccountId"

            if ($currentMgContext.ClientId -ne $currentAzContext.Account.Id) {
                Write-Information -MessageData "MgContext ClientId does NOT match with AzContext AccountId `n reconnecting to MgGraph using application [$currentAzContext.Account.Id]"

                if ($null -ne $currentMgContextndition) {
                    # disconnecting current session and context
                    Disconnect-MgGraph
                }

                # reconnecting with AzContext application
                $graphTokenObject = Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com'
                Connect-MgGraph -AccessToken $graphTokenObject.Token
            } else {
                Write-Information -MessageData "MgContext ClientId is equal to AzContext AccountId, both are already connect via application [$($currentAzContext.Account.Id)]"
            }
            Write-Information -MessageData "Full connection is established `n"
        } else {
            Write-Error -Message "No active azure context was not found, make sure you are connected via Connect-AzAccount `n" -ErrorAction Stop
        }
    } catch {
        Write-Output "An error occurred during authorization"
        Write-Output $_
    }
}
