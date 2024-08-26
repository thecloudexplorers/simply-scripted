#Requires -PSEdition Core

<#
    .SYNOPSIS
    TODO

    .DESCRIPTION
    TODO

    .EXAMPLE
    TODO

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
function Convert-TokensToValues {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $MetadataCollection,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $TargetFilePath,

        [ValidateNotNullOrEmpty()]
        [System.String] $CustomOutputFilePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $StartTokenPattern,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $EndTokenPattern
    )

    try {
        Write-Debug -Message "Loading  target file [$TargetFilePath]"
        $targetFileContent = Get-Content -Path $TargetFilePath -Raw

        # Loop trough all keys to check if they match with possible tokens in the current line
        $MetadataCollection.Keys.ForEach{
            $currentMetadataKey = $_
            $constructedToken = "{0}{1}{2}" -f $StartTokenPattern, $currentMetadataKey, $EndTokenPattern

            # If a match is found replace the token with the value of the hashtable
            if ($targetFileContent -match $constructedToken) {
                $targetFileContent = $targetFileContent.Replace($constructedToken, $MetadataCollection[$currentMetadataKey])
            }
        }

        # Verify if all tokens have been replaced
        if ($targetFileContent.Contains($StartTokenPattern) -or $targetFileContent.Contains($EndTokenPattern)) {

            # Create a regex pattern from the StartTokenPattern
            foreach ($char in $StartTokenPattern.ToCharArray()) {
                # Add a backslash followed by the character to the output string
                $startTokenPatternOutput += "\" + $char
            }

            $regExLeft = [regex] $startTokenPatternOutput
            $matchForLeft = $targetFileContent | Select-String -Pattern $regExLeft -AllMatches

            # Create a regex pattern for the EndTokenPattern
            foreach ($char in $EndTokenPattern.ToCharArray()) {
                # Add a backslash followed by the character to the output string
                $endTokenPatternOutput += "\" + $char
            }

            $regExRight = [regex] $endTokenPatternOutput
            $matchForRight = $targetFileContent | Select-String -Pattern $regExRight -AllMatches

            # Check for tokens which are missing an start or an end pattern, meaning they are not closed
            if ($matchForLeft.Matches.Count -ne $matchForRight.Matches.Count) {
                if ($matchForLeft.Matches.Count -gt $matchForRight.Matches.Count) {

                    $missingEndTokenIndex = $matchForLeft.Matches.Index -join ', '
                    Write-Information -Message "One or more closing tokens [$EndTokenPattern] are missing!"
                    Write-Information -Message "Character index locations of the placeholder values with missing tokens: $missingEndTokenIndex"
                } elseif ($matchForLeft.Matches.Count -lt $matchForRight.Matches.Count) {

                    $missingStartTokenIndex = $matchForRight.Matches.Index -join ', '
                    Write-Information -Message "One or more open tokens [$StartTokenPattern] are missing!"
                    Write-Information -Message "Character index locations of the placeholder values with missing tokens: $missingStartTokenIndex"
                }
            } else {
                # Not all tokens have been replaces, show a warning

                # Create a regex pattern for the tokens based on the StartTokenPattern and EndTokenPattern
                $formattedRegEx = "{0}(.+?){1}" -f $startTokenPatternOutput, $endTokenPatternOutput
                $regEx = [regex] $formattedRegEx

                $matchInfo = $targetFileContent | Select-String -Pattern $regEx -AllMatches

                # Get the unique match values
                $matchValues = $matchInfo | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | Get-Unique

                # Create a string from the match values
                $warningValues = $matchValues -join ', '

                Write-Information -Message "Unreplaced tokens detected, make sure the MetadataCollection parameter contains all tokens"
                Write-Information -Message "Unreplaced tokens: $warningValues"
            }
        }

        # If the CustomOutputFilePath parameter has not been provided the original file will be replaced
        if ($CustomOutputFilePath.Length -eq 0) {
            $outputFilePath = $TargetFilePath
            Write-Debug -Message " no custom output filepath specified, original file will be overwritten"
        } else {
            $outputFilePath = $CustomOutputFilePath
            Write-Debug -Message " custom output filepath specified, original file will not be modified"
        }

        # save file to disk, since filetype is json UTF8 encoding is applied
        $targetFileContent | Out-File -FilePath $outputFilePath -Encoding UTF8

    } catch {
        Write-Host "An unexpected error with the following message occurred while converting tokens to values:"
        Write-Host $_.Exception.Message
    }
}
