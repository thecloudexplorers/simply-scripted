<#
.SYNOPSIS
    Converts a SecureString to plain text, intended to be used in combination
    with functions like Get-AzAccessToken in conjunction with APIs that require
    plain text input.

.DESCRIPTION
    This function decrypts a System.Security.SecureString and returns the
    original plain text string. It uses .NET marshaling to safely convert
    the encrypted SecureString to a BSTR (Basic String) pointer in unmanaged
    memory, reads the string value, and then properly cleans up the memory.

    The function ensures secure memory handling by:
    - Converting SecureString to a BSTR pointer in unmanaged memory
    - Reading the BSTR using the correct format-aware method
    - Zero-filling the memory before freeing to prevent data leakage
    - Using a try-finally block to guarantee cleanup even if errors occur

    WARNING: Converting SecureString to plain text defeats its security
    purpose. Only use when absolutely necessary (e.g., passing to APIs that
    require plain text) and avoid logging or storing the result.

.PARAMETER SecureString
    The SecureString object to convert to plain text.

.OUTPUTS
    System.String
    Returns the decrypted plain text string.

.EXAMPLE
    $secureBearerToken = $(Get-AzAccessToken).Token
    $params = @{
        SecureString = $secureBearerToken
    }
    $plainBearerToken = ConvertFrom-SecureStringToPlainText @params

    Converts a secure bearer token to plain text.

.EXAMPLE
    $secureString = ConvertTo-SecureString "MySecret123" -AsPlainText -Force
    $plain = ConvertFrom-SecureStringToPlainText $secureString
    Write-Host "Decrypted: $plain"

    Creates a SecureString and converts it back to plain text.

.NOTES
    - Uses BSTR (Basic String) format for proper COM interop compatibility
    - Memory is zero-filled before being freed for security
    - The finally block ensures cleanup even if conversion fails
    - Be cautious: plain text strings are not protected in memory

    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted

.LINK
    https://docs.microsoft.com/en-us/dotnet/api/system.security.securestring?wt.mc_id=DT-MVP-5005327
    https://docs.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.marshal?wt.mc_id=DT-MVP-5005327
#>
function ConvertFrom-SecureStringToPlainText {
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory)]
        [System.Security.SecureString] $SecureString
    )

    try {
        # Create a pointer to unmanaged memory for the string
        $basicString = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)

        # Convert the BSTR (basic String) to a regular string
        [System.String] $plainTextString = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($basicString)

        return $plainTextString
    } finally {
        # Always free the unmanaged memory to prevent memory leaks
        if ($basicString -ne [IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($basicString)
        }
    }
}
