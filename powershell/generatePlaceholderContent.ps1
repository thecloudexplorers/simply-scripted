
$nrOfEmailsToGenerate = 10
$sourceUpn = ""
$targetUpn = ""
$targetName = ""
$timeZone = "W. Europe Standard Time"

Import-Module Microsoft.Graph.Users.Actions
Import-Module Microsoft.Graph.Calendar

. .\powershell\functions\New-PlaceholderText.ps1
. .\powershell\functions\Get-StartAndEndDate.ps1

$eventLocationName = New-PlaceholderText -Number 5 -Words
$eventContent = New-PlaceholderText -Number 10 -Paragraphs

$params = @{
    subject               = $eventLocationName
    body                  = @{
        contentType = "Text"
        content     = $eventContent
    }
    start                 = @{
        dateTime = "2024-03-12T12:00:00"
        timeZone = $timeZone
    }
    end                   = @{
        dateTime = "2024-03-12T14:00:00"
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
New-MgUserCalendarEvent -UserId $sourceUpn -CalendarId $defaultCalendar.Id -BodyParameter $params

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
    Send-MgUserMail -UserId $sourceUpn -BodyParameter $params
    Write-Host "Mail sent to $targetUpn from $sourceUpn with title $mailTitle"
}
