#Requires -PSEdition Core
#Requires -Modules Az.ResourceGraph
<#
    .SYNOPSIS
        Applies drift control to an Azure DevOps audit stream to ensure audit
        logs are sent to a specified Log Analytics workspace.

    .DESCRIPTION
        This function applies drift control to an Azure DevOps audit stream to
        ensure audit logs are sent to a specified Log Analytics workspace. The
        function will query the existing audit streams in the Azure DevOps
        organization and delete any rogue streams. If the target Log Analytics
        workspace stream is present and not enabled, the function will enable
        it and ensure the correct configurations are set.

    .PARAMETER AdoAuthenticationHeader
        Specifies the authentication header for Azure DevOps REST API requests.

    .PARAMETER AdoOrganizationName
        Specifies the name of the Azure DevOps organization.

    .PARAMETER TargetLogAnalyticsWorkspaceName
        The name of the target Log Analytics Workspace where audit logs will
        be sent to.

    .PARAMETER TargetLogAnalyticsResourceGroup
        The name of the resource group of the target Log Analytics Workspace.

    .EXAMPLE

    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Basic ' + $authToken
    }

    $inputArgs = @{
        AdoAuthenticationHeader = $authHeader
        AdoOrganizationName = "my-organization"
        TargetLogAnalyticsWorkspaceName "YOUR_LAW_NAME"
        TargetLogAnalyticsResourceGroup "YOUR_LAW_RESOURCE_GROUP"
    }

    Set-AdoAuditStream @inputArgs

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers

    .LINK
    https://learn.microsoft.com/en-us/rest/api/azure/devops/audit/streams/create?view=azure-devops-rest-7.1&tabs=HTTP
#>

function Set-AdoAuditStream {
    [CmdLetBinding(SupportsShouldProcess)]
    [OutputType([System.Object])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoOrganizationName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $TargetLogAnalyticsWorkspaceName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $TargetLogAnalyticsResourceGroup

    )

    # Get Log Analytics Workspace properties
    try {

        Write-Information -MessageData "Fetching Log Analytics Workspace properties"
        $targetLaw = Search-AzGraph -Query "resources
        | where  type == 'microsoft.operationalinsights/workspaces'
        | where name == '$AdoLogAnalyticsWorkspaceName'"
        Write-Verbose -Message "Log Analytics WorkSpace ID [$($targetLaw.properties.CustomerId)]"

        # Ensure Log Analytics Workspace exists and thor an error if it does not
        if ($null -eq $targetLaw) { throw "Log Analytics Workspace [$AdoLogAnalyticsWorkspaceName] not found" }

        # Ensuring correct Az Context is set
        if ($currentAzContext.Subscription.Id -ne $targetLaw.subscriptionId) {
            Write-Information -MessageData "Setting current Az context to Log Analytics WorkSpace Subscription: [$($targetLaw.subscriptionId)]"
            Set-AzContext -Subscription $targetLaw.subscriptionId | Out-Null
        } else {
            Write-Host "Current Az Context is already set to Log Analytics WorkSpace Subscription, no action required"
        }

        Write-Host "Fetching Log Analytics Workspace shared key"
        $workspaceSharedKey = Get-AzOperationalInsightsWorkspaceSharedKey -Name $AdoLogAnalyticsWorkspaceName -ResourceGroupName $AdoLogAnalyticsResourceGroup
    } catch {
        Write-Error -Message "The following error occurred while fetching Log Analytics Workspace properties: [$($_.Exception.Message)]" -ErrorAction Stop
    }

    # Query existing audit stream in azure devops organization
    try {
        Write-Host "Querying present audit streams in the Azure DevOps organization"
        $streamQueryUrl = "https://auditservice.dev.azure.com/$AdoOrganizationName/_apis/audit/streams?api-version=6.1-preview.1"
        # getting all existing Streams
        $existingStreams = Invoke-RestMethod -Uri $streamQueryUrl -Method Get -Headers $AdoAuthenticationHeader
        # filtering stream collection to the supplied Log Analytics Workspace
        $targetLawStream = $existingStreams.value | Where-Object { ($_.consumerType -eq "AzureMonitorLogs") -and ($_.consumerInputs.WorkspaceId -eq $targetLaw.properties.CustomerId) }
        if ($targetLawStream.count -eq 1) {
            Write-Host "Target Log Analytics Workspace stream is present"
        }
        # getting any rogue streams if present, to be deleted
        $rogueStreams = $existingStreams.value | Where-Object { $_.id -ne $targetLawStream.id }
        if ($rogueStreams.count -gt 0) {
            Write-Host "Detected [$($rogueStreams.count)] rogue audit streams, queuing rogue streams for deletion"
        }

    } catch {
        Write-Error -Message "The following error occurred while querying available audit streams: [$($_.Exception.Message)]" -ErrorAction Stop
    }

    # Delete all rogue audit streams
    try {
        if ($null -ne $rogueStreams) {
            Write-Host "Deleting all rogue audit streams"
            foreach ($stream in $rogueStreams) {
                $streamDeleteUrl = "https://auditservice.dev.azure.com/$AdoOrganizationName/_apis/audit/streams/$($stream.id)?api-version=6.1-preview.1"
                if ($PSCmdlet.ShouldProcess($streamDeleteUrl, "Invoke-RestMethod")) {
                    Invoke-RestMethod -Uri $streamDeleteUrl -Method 'DELETE' -Headers $AdoAuthenticationHeader
                }
                Write-Host "Rogue audit stream [$stream] deleted"
            }
        }
    } catch {
        Write-Error -Message "The following error occurred while deleting rogue audit streams: [$($_.Exception.Message)]" -ErrorAction Stop
    }

    # If the log analytics stream exists and not enabled, ensure it is enabled and has the right configurations (drift control)
    if ($null -ne $targetLawStream) {

        if ($targetLawStream.status -eq 'enabled' ) {
            Write-Host "Target Log Analytics Audit stream is detected and enabled, no drift detected"
        }

        if ($targetLawStream.status -ne 'enabled' ) {
            Write-Warning -Message "Target Log Analytics Audit stream found in  disabled state, applying drift control.."
            $streamUpdateUrl = "https://auditservice.dev.azure.com/$AdoOrganizationName/_apis/audit/streams?api-version=6.1-preview.1"
            $streamUpdateObject = @{
                id             = $targetLawStream.id
                consumerInputs = @{
                    WorkspaceId = $targetLaw.properties.CustomerId
                    SharedKey   = $workspaceSharedKey.PrimarySharedKey
                }
                consumerType   = "AzureMonitorLogs"
            }
            $streamUpdateJsonObject = $streamUpdateObject | ConvertTo-Json -Depth 10
            try {
                Write-Host "Updating the target Log Analytics Workspace audit stream configuration"
                if ($PSCmdlet.ShouldProcess($streamUpdateUrl, "Invoke-RestMethod")) {
                    Invoke-RestMethod -Uri $streamUpdateUrl -Method 'PUT' -Headers $AdoAuthenticationHeader -Body $streamUpdateJsonObject
                }
                Write-Host "Enabling the target Log Analytics Workspace audit stream"
                $streamEnableUrl = "https://auditservice.dev.azure.com/$AdoOrganizationName/_apis/audit/streams/$($targetLawStream.id)?status=enabled&api-version=7.2-preview.1"
                if ($PSCmdlet.ShouldProcess($streamEnableUrl, "Invoke-RestMethod")) {
                    Invoke-RestMethod -Uri $streamEnableUrl -Method 'PUT' -Headers $AdoAuthenticationHeader
                }
            } catch {
                Write-Error -Message "The following error occurred while attempting to enable and update the audit stream: [$($_.Exception.Message)]" -ErrorAction Stop
            }
        }
    }

    # If the log analytics stream does not exist, create a new one
    else {
        Write-Warning -Message "Log Analytics Workspace Audit stream does not exist, applying drift control.."
        $streamCreateUrl = "https://auditservice.dev.azure.com/$AdoOrganizationName/_apis/audit/streams?daysToBackfill=2&api-version=7.2-preview.1"
        $streamCreateObject = @{
            consumerInputs = @{
                WorkspaceId = $targetLaw.properties.CustomerId
                SharedKey   = $workspaceSharedKey.PrimarySharedKey
            }
            consumerType   = "AzureMonitorLogs"
        }
        $streamCreateJsonObject = $streamCreateObject | ConvertTo-Json -Depth 10
        try {
            Write-Hosts "Creating the target Log Analytics Workspace audit stream"
            if ($PSCmdlet.ShouldProcess($streamCreateUrl, "Invoke-RestMethod")) {
                Invoke-RestMethod -Uri $streamCreateUrl -Method 'POST' -Headers $AdoAuthenticationHeader -Body $streamCreateJsonObject
            }
        } catch {
            Write-Error -Message "The following error occurred while attempting to create the audit stream: [$($_.Exception.Message)]" -ErrorAction Stop
        }
    }
}
