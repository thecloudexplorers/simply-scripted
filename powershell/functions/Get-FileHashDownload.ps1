<#
    .SYNOPSIS
    Get file hash for an online file.

    .DESCRIPTION
    Download a file from any online source, get the file hash for that file, and optionally determine if the hash matches a predefined hash as published by the author.

    .EXAMPLE
    Get-FileHashDownload -Url "https://gist.githubusercontent.com/bearmannl/ed044a36842c66834d2421342f36b8d6/raw/f13d6349b650cec674cd593a86bc28d4222c712f/Get-FileHashDownload.ps1"

    .NOTES
    Author: Mike Beerman - @bearmannl | https://github.com/bearmannl
#>

function Get-FileHashDownload {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$Url,
        [String]$KnownHash,
        [Switch]$JustHash
    )
    
    $webClient = [System.Net.WebClient]::new()
    $fileHash = Get-FileHash -InputStream ($webClient.OpenRead($Url))
    
    if ($JustHash) {
        $fileHash.Hash
    }
    else {
        Write-Host "Your downloaded file has the following hash:"
        $fileHash.Hash
    
        if ($KnownHash) {
            Write-Host " "
            Write-Host "Does the download hash match? $($fileHash.Hash -eq $KnownHash)"
        }        
    }
}
