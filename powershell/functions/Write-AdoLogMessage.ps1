<#
    .SYNOPSIS
    Writes a log entry using Azure DevOps pipeline logging commands.

    .DESCRIPTION
    This function writes a message to the Azure DevOps pipeline log.

    Information entries are written as plain messages, optionally decorated with an Azure DevOps
    formatting command such as ##[group] or ##[section].

    Warning and Error entries are emitted as ##vso[task.logissue] commands so they show up in the
    pipeline run summary. Special characters in the message are escaped so that multi-line
    messages are logged as a single issue.

    An Error entry combined with -Action Stop additionally terminates the script.

    .PARAMETER Message
    The message to log.

    .PARAMETER Type
    The type of log entry. Accepts "Information", "Warning" or "Error".

    .PARAMETER FormatType
    Optional Azure DevOps formatting command applied to Information entries.
    Accepts "Group", "Warning", "Error", "Debug", "Section", "Command" or "Endgroup".

    .PARAMETER Action
    Optional, applies to Error entries only. Accepts "Continue" or "Stop". "Stop" throws after
    logging the error, "Continue" or omitted only logs it.

    .EXAMPLE
    $logArgs = @{
        Message    = "Validating branches"
        Type       = "Information"
        FormatType = "Section"
    }
    Write-AdoLogMessage @logArgs

    .EXAMPLE
    $logArgs = @{
        Message = "Branch is stale"
        Type    = "Warning"
    }
    Write-AdoLogMessage @logArgs

    .EXAMPLE
    $logArgs = @{
        Message = "Validation failed"
        Type    = "Error"
        Action  = "Stop"
    }
    Write-AdoLogMessage @logArgs

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
    Credits     : Based on the original Write-ConsoleLogMessage by Iliyan Iliev

    .LINK
    https://learn.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands?wt.mc_id=DT-MVP-5005327
#>
function Write-AdoLogMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Message,

        [Parameter(Mandatory)]
        [ValidateSet("Information", "Warning", "Error")]
        [System.String] $Type,

        [Parameter()]
        [ValidateSet("Group", "Warning", "Error", "Debug", "Section", "Command", "Endgroup")]
        [System.String] $FormatType,

        [Parameter()]
        [ValidateSet("Continue", "Stop")]
        [System.String] $Action
    )

    if ($Type -eq "Information") {
        $formattedMessage = if ($FormatType) { "##[{0}]{1}" -f $FormatType.ToLower(), $Message } else { $Message }
        # Write-Host avoids the SilentlyContinue default of the information stream
        Write-Host $formattedMessage
        return
    }

    # Logging commands are single-line, so escape characters that would otherwise break the command
    $escapedMessage = $Message.Replace('%', '%AZP25').Replace("`r", '%0D').Replace("`n", '%0A')

    # Written to stdout as-is, Write-Warning/Write-Error would prefix the line and prevent command parsing
    Write-Host ("##vso[task.logissue type={0}]{1}" -f $Type.ToLower(), $escapedMessage)

    if ($Type -eq "Error" -and $Action -eq "Stop") {
        throw $Message
    }
}
