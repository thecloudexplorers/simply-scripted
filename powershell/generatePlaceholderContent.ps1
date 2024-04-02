#Requires -PSEdition Desktop
#Requires -Modules Microsoft.Graph.Users.Actions
#Requires -Modules Microsoft.Graph.Calendar

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
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

[CmdLetBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.Int32] $nrOfEmailsToGenerate = 200,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.Int32] $nrOfEventsToGenerate = 500,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $sourceUpn,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [System.String] $targetUpn

)

Import-Module Microsoft.Graph.Users.Actions
Import-Module Microsoft.Graph.Calendar
Import-Module Microsoft.Graph.Users.Functions

. .\powershell\functions\New-PlaceholderText.ps1
. .\powershell\functions\Get-StartAndEndDate.ps1

# Get the correct time zone for Amsterdam.
Invoke-MgTimeUserOutlook -UserId $sourceUpn
$amsterdamTimeZone = $timeZones | where-Object { $_.DisplayName -like "(*Amsterdam*" }

for ($i = 0; $i -lt $nrOfEventsToGenerate; $i++) {
    $eventLocationName = New-PlaceholderText -Number 5 -Words
    $eventContent = New-PlaceholderText -Number 10 -Paragraphs

    $eventDates = Get-StartAndEndDate -TimeSpanStartDate $(Get-Date) -TimeSpanEndDate $(Get-Date).AddYears(2)

    $params = @{
        subject               = $eventLocationName
        body                  = @{
            contentType = "Text"
            content     = $eventContent
        }
        start                 = @{
            dateTime = $eventDates.RandomStartDate
            timeZone = $amsterdamTimeZone.Alias
        }
        end                   = @{
            dateTime = $eventDates.RandomEndDate
            timeZone = $amsterdamTimeZone.Alias
        }
        location              = @{
            displayName = $eventLocationName
        }
        attendees             = @(
            @{
                emailAddress = @{
                    address = $targetUpn
                    name    = $targetName
                }
                type         = "required"
            }
        )
        isOnlineMeeting       = $true
        onlineMeetingProvider = "teamsForBusiness"
    }

    # A UPN can also be used as -UserId.
    $defaultCalendar = Get-MgUserCalendar -UserId $sourceUpn | Where-Object Name -eq 'Calendar'
    New-MgUserCalendarEvent -UserId $sourceUpn -CalendarId $defaultCalendar.Id -BodyParameter $params > $null
    Write-Host "Event [$i/$nrOfEventsToGenerate] created for $targetUpn starting at [$($eventDates.RandomStartDate)] ending [$($eventDates.RandomEndDate)] with title $eventLocationName"
}

for ($i = 0; $i -lt $nrOfEmailsToGenerate; $i++) {
    $mailTitle = New-PlaceholderText -Number 5 -Words
    $mailBody = New-PlaceholderText -Number 10 -Paragraphs

    $params = @{
        message         = @{
            subject      = "Demo Email: $mailTitle"
            body         = @{
                contentType = "Text"
                content     = $mailBody
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = $targetUpn
                    }
                }
            )
            ccRecipients = @(
                @{
                    emailAddress = @{
                        address = $sourceUpn
                    }
                }
            )
        }
        saveToSentItems = "true"
    }

    # A UPN can also be used as -UserId.
    # https://learn.microsoft.com/en-us/graph/api/user-sendmail?view=graph-rest-1.0&tabs=powershell#example-1-send-a-new-email-using-json-format
    Send-MgUserMail -UserId $sourceUpn -BodyParameter $params > $null
    Write-Host "Mail [$i/$nrOfEmailsToGenerate] sent to $targetUpn from $sourceUpn with title $mailTitle"
}
