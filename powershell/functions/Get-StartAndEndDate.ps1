<#
    .SYNOPSIS
    The Get-StartAndEndDate function generates random start and end dates within a given date range.

    .DESCRIPTION
    The function requires two DateTime parameters, TimeSpanStartDate and TimeSpanEndDate, ensuring that the start date is not later than the end date. It calculates the total days between these two dates and generates a random number within this range, which is added to the start date to yield a random start date.

    To ensure that the random end date is always later than the random start date, the function calculates the remaining days and generates another random number within this range. This number is added to the random start date to produce the random end date. The function then returns these two randomly generated dates.

    .PARAMETER TimeSpanStartDate
    A mandatory parameter that specifies the start date of the range.

    .PARAMETER TimeSpanEndDate
    A mandatory parameter that specifies the end date of the range.

    .OUTPUTS
    DateTime[]. The function returns an array of two DateTime objects - a randomly generated start date and end date within the provided range.

    .EXAMPLE
    $currentDate = Get-Date

    $myArgs = @{
        TimeSpanStartDate = $currentDate
        TimeSpanEndDate   = $currentDate.AddYears(2)
    }
    Get-StartAndEndDate @params

    This example demonstrates how to use a splatting expression to generate a random start and end date within the year 2022.

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

#>

function Get-StartAndEndDate {
    param(
        [Parameter(Mandatory)]
        [System.DateTime]$TimeSpanStartDate,

        [Parameter(Mandatory)]
        [ValidateScript({
                if ($TimeSpanStartDate -gt $_) {
                    throw "StartDateTimeSpan cannot be later than EndDateTimeSpan"
                }
                return $true
            })]
        [System.DateTime]$TimeSpanEndDate
    )

    # Calculate the number of days between the start and end date
    $daysSpan = ($TimeSpanEndDate - $TimeSpanStartDate).Days
    # Generate a random number of days with the maximum as the number of days between the start and end date
    $randomStartDays = Get-Random -Minimum 0 -Maximum $daysSpan
    # Add the random number of days to the start date, this will now be our random start date
    $randomStartDate = $TimeSpanStartDate.AddDays($randomStartDays)

    # Make sure that randomEndDate is always later than randomStartDate, by calculating the remaining days
    $remainingDays = $daysSpan - $randomStartDays
    # Generate a random number of days with the maximum as the remaining days
    $randomEndDays = Get-Random -Minimum 0 -Maximum $remainingDays

    # Add the random number of days to the random start date, this will now be our random end date
    $randomEndDate = $randomStartDate.AddDays($randomEndDays)

    return [PSCustomObject]@{
        RandomStartDate = [System.DateTime]$randomStartDate
        RandomEndDate   = [System.DateTime]$randomEndDate
    }
}


$currentDate = Get-Date

$myArgs = @{
    TimeSpanStartDate = $currentDate
    TimeSpanEndDate   = $currentDate.AddYears(2)
}

$lol = Get-StartAndEndDate @myArgs
