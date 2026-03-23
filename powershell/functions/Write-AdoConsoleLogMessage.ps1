<#
    .SYNOPSIS
    Writes formatted Azure DevOps console log messages.

    .DESCRIPTION
    Write-ConsoleLogMessage writes log entries for Azure DevOps pipelines.

    When Type is Information, the message is written as plain text or with an
    optional Azure DevOps formatting prefix (for example Section or Group).

    When Type is Warning or Error, the function emits Azure DevOps task logissue
    commands and writes warning/error output. It can also apply the matching
    PowerShell action preference through the Action parameter.

    .PARAMETER Message
    Message text to write to the console.

    .PARAMETER Type
    Log issue type to emit. Valid values are Warning, Error, and Information.

    .PARAMETER AdoFormatType
    Optional Azure DevOps formatting command for informational output.
    Valid values are Group, Warning, Error, Debug, Section, Command, and
    Endgroup.

    .PARAMETER ErrorAction
    Optional action preference for warning and error output.
    Valid values are Continue, Stop, SilentlyContinue, and Inquire.

    .EXAMPLE
    $parameters = @{
        Message       = 'Starting deployment'
        Type          = 'Information'
        AdoFormatType = 'Section'
    }
    Write-ConsoleLogMessage @parameters

    Writes a section-formatted informational message to the Azure DevOps console.

    .EXAMPLE
    $parameters = @{
        Message     = 'Validation found non-blocking issues'
        Type        = 'Warning'
        ErrorAction = 'Continue'
    }
    Write-ConsoleLogMessage @parameters

    Writes a warning issue entry and continues execution.

    .EXAMPLE
    $parameters = @{
        Message     = 'Deployment failed'
        Type        = 'Error'
        ErrorAction = 'Stop'
    }
    Write-ConsoleLogMessage @parameters

    Writes an error issue entry and stops execution.

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
function Write-ConsoleLogMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $Message,

        [Parameter(Mandatory)]
        [ValidateSet("Warning", "Error", "Information")]
        [System.String] $Type,

        [Parameter()]
        [ValidateSet("Group", "Warning", "Error", "Debug", "Section", "Command", "Endgroup")]
        [System.String] $AdoFormatType,

        [Parameter()]
        [ValidateSet("Continue", "Stop", "SilentlyContinue", "Inquire")]
        [System.String] $ErrorAction
    )

    if ($Type -eq "Information") {
        if (-not [string]::IsNullOrEmpty($AdoFormatType)) {
            $formattedMessage = $formattedMessage = "##[{0}]{1}" -f $AdoFormatType.ToLower(), $Message
        } else {
            $formattedMessage = $Message
        }
        Write-Host $formattedMessage
    } else {
        $formattedMessage = "##vso[task.logissue type={0}]{1}" -f $Type.ToLower(), $Message
        $logParam = @{
            Message = $formattedMessage
        }
        switch ($Type) {
            'Warning' {
                if ('' -ne $ErrorAction) {
                    $logParam.Add('WarningAction', $ErrorAction)
                }
                Write-Host "##vso[task.complete result=SucceededWithIssues;]"
                Write-Warning @logParam
            }
            'Error' {
                if ('' -ne $ErrorAction) {
                    $logParam.Add('ErrorAction', $ErrorAction)
                }
                Write-Host "##vso[task.complete result=Failed;]"
                Write-Error @logParam
            }
        }
    }
}
