
$nrOfEmailsToGenerate = 200
$nrOfEventsToGenerate = 500
$sourceUpn = ""
$targetUpn = ""
$targetName = ""
$timeZone = "W. Europe Standard Time"

Import-Module Microsoft.Graph.Users.Actions
Import-Module Microsoft.Graph.Calendar

. .\powershell\functions\New-PlaceholderText.ps1
. .\powershell\functions\Get-StartAndEndDate.ps1


for ($i = 0; $i -lt $nrOfEventsToGenerate; $i++) {
    <# Action that will repeat until the condition is met #>

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
            timeZone = $timeZone
        }
        end                   = @{
            dateTime = $eventDates.RandomEndDate
            timeZone = $timeZone
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
