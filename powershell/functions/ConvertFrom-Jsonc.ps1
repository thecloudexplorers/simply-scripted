<#
    .SYNOPSIS
    Converts JSONC content to an object.

    .DESCRIPTION
    This function removes // line comments and /* */ block comments from a string
    containing JSONC-style content, then converts the result with ConvertFrom-Json.

    The function scans the input character by character and applies the following rules:

    - Comments starting with // are removed up to the end of the line; the line break is kept.
    - Comments between /* and */ are removed, including across multiple lines.
    - Comment-like text inside quoted string values is left untouched.

    Progress is written to the host, and a warning is written when a /* comment is never closed.
    Other JSONC extensions, such as trailing commas, are not handled. Invalid JSON after the
    comments are removed causes ConvertFrom-Json to throw.

    .PARAMETER JsoncContent
    The raw JSONC content as a string. This may contain // line comments and
    /* */ block comments.

    .EXAMPLE
    $jsonc = @'
    {
        // This is a comment
        "name": "example", // Inline comment
        "value": 1
    }
    '@

    $object = ConvertFrom-Jsonc -JsoncContent $jsonc

    .EXAMPLE
    $fileContent = Get-Content -Path ".\settings.jsonc" -Raw
    $object = ConvertFrom-Jsonc -JsoncContent $fileContent

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
function ConvertFrom-Jsonc {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.String] $JsoncContent
    )

    Write-Host "Removing comments from JSONC content of [$($JsoncContent.Length)] characters."

    $cleanedContent = [System.Text.StringBuilder]::new()

    # The parser is always in exactly one of these places while it walks through the text
    $inString = $false
    $inLineComment = $false
    $inBlockComment = $false

    # True right after a backslash inside a string, so an escaped quote (\") does not end the string
    $isEscaped = $false

    $lineCommentCount = 0
    $blockCommentCount = 0

    for ($index = 0; $index -lt $JsoncContent.Length; $index++) {
        $currentChar = $JsoncContent[$index]

        # Look one character ahead to recognize the two-character markers // /* */
        $hasNextChar = ($index + 1) -lt $JsoncContent.Length
        $nextChar = if ($hasNextChar) { $JsoncContent[$index + 1] } else { [System.Char] 0 }

        if ($inLineComment) {
            # A line comment ends at the line break; keep the break so the lines stay separated
            if ($currentChar -eq "`r" -or $currentChar -eq "`n") {
                $inLineComment = $false
                [System.Void] $cleanedContent.Append($currentChar)
            }
        } elseif ($inBlockComment) {
            if ($currentChar -eq '*' -and $nextChar -eq '/') {
                $inBlockComment = $false
                # Skip the '/' of the closing marker as well
                $index++
            }
        } elseif ($inString) {
            # Everything inside quotes is real content, even if it looks like a comment
            [System.Void] $cleanedContent.Append($currentChar)

            if ($isEscaped) {
                $isEscaped = $false
            } elseif ($currentChar -eq '\') {
                $isEscaped = $true
            } elseif ($currentChar -eq '"') {
                $inString = $false
            }
        } elseif ($currentChar -eq '"') {
            $inString = $true
            [System.Void] $cleanedContent.Append($currentChar)
        } elseif ($currentChar -eq '/' -and $nextChar -eq '/') {
            Write-Host "Removing line comment found at position [$index]."
            $inLineComment = $true
            $lineCommentCount++
            # Skip the second '/' of the opening marker
            $index++
        } elseif ($currentChar -eq '/' -and $nextChar -eq '*') {
            Write-Host "Removing block comment found at position [$index]."
            $inBlockComment = $true
            $blockCommentCount++
            # Skip the '*' of the opening marker
            $index++
        } else {
            # Regular JSON content outside strings and comments
            [System.Void] $cleanedContent.Append($currentChar)
        }
    }

    if ($inBlockComment) {
        Write-Warning 'A block comment was opened with /* but never closed with */; the rest of the content was removed.'
    }

    Write-Host "Removed [$lineCommentCount] line comment(s) and [$blockCommentCount] block comment(s); [$($cleanedContent.Length)] characters remain."

    return $cleanedContent.ToString() | ConvertFrom-Json -ErrorAction Stop
}
