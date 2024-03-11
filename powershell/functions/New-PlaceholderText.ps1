<#
    .SYNOPSIS
    This function generates placeholder text based on hte famous "Lorem Ipsum" .

    .DESCRIPTION
    This function generates "Lorem Ipsum" placeholder text either as paragraphs or as words. The user can
    specify the number of paragraphs or words they want to generate.

    .PARAMETER Words
    If this switch is used, the function will generate the specified number of random "Lorem Ipsum" words.

    .PARAMETER Paragraphs
    If this switch is used, the function will generate the specified number of "Lorem Ipsum" paragraphs.

    .PARAMETER number
    This parameter specifies the number of words or paragraphs to generate. It must be a number between 1 and 100.

    .EXAMPLE
    $wordsParams = @{
        Words = $true
        number = 50
    }
    New-LoremIpsum @wordsParams
    This command generates 50 random "Lorem Ipsum" words using splatting.

    .EXAMPLE
    $paraParams = @{
        Paragraphs = $true
        number = 5
    }
    New-LoremIpsum @paraParams
    This command generates 5 "Lorem Ipsum" paragraphs using splatting.

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

#>

function New-PlaceholderText {
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 100)]
        [System.Int32]$Number,

        [Parameter(Mandatory, ParameterSetName = 'Words')]
        [System.Management.Automation.SwitchParameter]$Words,

        [Parameter(Mandatory, ParameterSetName = 'Paragraphs')]
        [System.Management.Automation.SwitchParameter]$Paragraphs
    )

    $loremIpsum = @"
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud
exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute
irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla
pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia
deserunt mollit anim id est laborum.
"@

    if ($Paragraphs.IsPresent) {
        $result = $loremIpsum * $Number
    } elseif ($Words.IsPresent) {
        $randomWords = $loremIpsum -split ' ' | Get-Random -Count $Number
        $result = [string]::Join(" ", $randomWords)
    } else {
        Write-Error "You must specify either -Words or -Paragraphs"
    }

    return $result
}
