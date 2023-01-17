#Requires -Modules Az
<#
    .SYNOPSIS
    Use this function to purge a soft deleted API management instance

    .DESCRIPTION
    When you use the Azure portal or REST API version 2020-06-01-preview or later to delete an API Management instance,
    it's soft-deleted and recoverable during a retention period. This function calls the API Management Purge operation
    to permanently delete the concerned soft-deleted instance.

    .PARAMETER SubscriptionId
    Subscription Id of the concerning Api Management Instance

    .PARAMETER Location
    Azure location/region of the concerning Api Management Instance

    .PARAMETER ApiManagementInstanceName
    Name of the concerning Api Management Instance

    .EXAMPLE
    $apimArgs = @{
        SubscriptionId              = "d8852164-1d48-4887-82d2-022294a5b912"
        Location                    = "West Europe"
        ApiManagementInstanceName   = "my-apim"
    }
    Remove-SoftDeletedApiManagementInstance @apimArgs

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

    .LINK
    https://docs.microsoft.com/en-us/azure/api-management/soft-delete
#>


function Remove-SoftDeletedApiManagementInstance {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $SubscriptionId,


        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Location,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ApiManagementInstanceName
    )


    Begin {
        # Get bearer token
        $currentContext = Get-AzAccessToken
        $authHeader = @{
            'Content-Type'  = 'application/json'
            'Authorization' = 'Bearer ' + $currentContext.Token
        }
    }

    Process {

        $restUri = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.ApiManagement/locations/{1}/deletedservices/{2}?api-version=2021-08-01" -f $SubscriptionId, $Location, $ApiManagementInstanceName
        $response = Invoke-RestMethod -Uri $restUri -Method 'Delete' -Headers $authHeader
        Write-Information -MessageData "Soft deleted Api Management instance [$($response.name)] has been scheduled for purge at [$($response.properties.scheduledPurgeDate)] UTC"
    }
}
