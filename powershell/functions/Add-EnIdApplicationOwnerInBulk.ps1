#Requires -PSEdition Desktop
#Requires -Modules Az
<#
    .SYNOPSIS
    This function add the specified user as owner of the specified App
    Registrations.

    .DESCRIPTION
    This function adds the specified user (as additional) as owner to
    all App registration part of the supplied collection. The email of
    the user in question is used.

    .PARAMETER EnIdApplicationCollection
    Collection of Entra ID Application objects

    .PARAMETER NewOwnerEmail
    Email of the new owner, must be a valid SPN of an existing user

    .EXAMPLE
    $currentApps = Get-AzADApplication -DisplayNameStartWith "MyPurposeApps"

    $newOwnerArgs = @{
        EnIdApplicationCollection   = $currentApps
        NewOwnerEmail               = "devjev@demojev.nl"
    }
    Add-EnIdApplicationOwnerInBulk @newOwnerArgs

    .NOTES
    Version:    : 2.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function Add-EnIdApplicationOwnerInBulk {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $EnIdApplicationCollection,

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
            $EnIdApplicationCollection.ForEach{
                $EnIdApp = $_

                Write-Host "Processing AD application [$($EnIdApp.DisplayName)]]"
                $currentOwners = Get-AzureADApplicationOwner -ObjectId $EnIdApp.id
                $userIsCurrentOwner = $currentOwners | Where-Object { $_.Mail -eq $currentUser.Account.Id }

                if ($userIsCurrentOwner) {
                    Write-Host " Adding user [$($newOwner.DisplayName) as owner to [$($EnIdApp.DisplayName)]]"
                    $userIsOwner = $currentOwners | Where-Object { $_.Mail -eq $NewOwnerEmail }

                    if ($userIsOwner) {
                        Write-Host "  User [$($newOwner.DisplayName) ] is alspready owner of [$($EnIdApp.DisplayName)]"
                    } else {
                        Add-AzureADApplicationOwner -ObjectId $EnIdApp.id -RefObjectId $newOwner.Id
                        Write-Host "  User has been added"
                    }
                } else {
                    Write-Host " Current context identity [$($currentUser.Account.Id)] is not an owner of [$($EnIdApp.DisplayName)], skipping"
                }
            }

        } else {
            Write-Warning -Message "Unable to add new Application owner as no user has been found with email [$NewOwnerEmail]"
        }
    }
}
