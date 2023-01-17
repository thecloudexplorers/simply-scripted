#Requires -PSEdition Desktop
#Requires -Modules Az
<#
    .SYNOPSIS
    This function add the specified user as owner of the specified App Registrations

    .DESCRIPTION
    This function adds the specified user (as additional) as owner to
    all App registration part of the supplied collection. The email of the user in question is used.

    .EXAMPLE
    $currentApps = Get-AzADApplication -DisplayNameStartWith "MyPurposeApps"

    $newOwnerArgs = @{
        AzAdApplicationCollection   = $currentApps
        NewOwnerEmail               = "devjev@demojev.nl"
    }
    Add-NewApplicationOwnerInBulk @newOwnerArgs

    .NOTES
    Author: Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function Add-NewApplicationOwnerInBulk {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $AzAdApplicationCollection,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $NewOwnerEmail
    )

    Begin {

        $filter = "Mail eq '{0}'" -f $NewOwnerEmail
        $newOwner = Get-AzureADUser -Filter $filter
        $currentUser = Get-AzureADCurrentSessionInfo
    }

    Process {
        if ($newOwner) {
            $AzAdApplicationCollection.ForEach{
                $AzAdApp = $_

                Write-Information -MessageData "Processing AD application [$($AzAdApp.DisplayName)]]"
                $currentOwners = Get-AzureADApplicationOwner -ObjectId $AzAdApp.id
                $userIsCurrentOwner = $currentOwners | Where-Object { $_.Mail -eq $currentUser.Account.Id }

                if ($userIsCurrentOwner) {
                    Write-Information -MessageData " Adding user [$($newOwner.DisplayName) as owner to [$($AzAdApp.DisplayName)]]"
                    $userIsOwner = $currentOwners | Where-Object { $_.Mail -eq $NewOwnerEmail }

                    if ($userIsOwner) {
                        Write-Information -MessageData "  User [$($newOwner.DisplayName) ] is alspready owner of [$($AzAdApp.DisplayName)]"
                    } else {
                        Add-AzureADApplicationOwner -ObjectId $AzAdApp.id -RefObjectId $newOwner.Id
                        Write-Information -MessageData "  User has been added"
                    }
                } else {
                    Write-Information -MessageData " Current context identity [$($currentUser.Account.Id)] is not an owner of [$($AzAdApp.DisplayName)], skipping"
                }
            }

        } else {
            Write-Warning "Unable to add new Application owner as no user has been found with email [$NewOwnerEmail]"
        }
    }
}
