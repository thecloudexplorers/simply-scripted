<#
.SYNOPSIS
    Reads Azure DevOps organizations connected to an Entra ID tenant.

.DESCRIPTION
    Queries the Azure DevOps EnterpriseCatalog API to retrieve all organizations
    connected to the specified Entra ID (Azure AD) tenant. The function
    downloads and parses CSV data containing organization details, ownership
    information, and any connection errors. This function provides tenant-level
    governance capabilities by identifying all Azure DevOps organizations within
    scope.

.PARAMETER TenantId
    The GUID of the Entra ID tenant (not the display name). This value is used
    in the EnterpriseCatalog API request.

.PARAMETER AdoBearerBasedAuthenticationHeader
    A hashtable containing the Authorization header for the request, e.g.
    @{ Authorization = "Bearer <access-token>" }. This header must be valid and
    have the required permissions to query billing details.

.OUTPUTS
    System.Collections.ArrayList
        A collection of PSCustomObject entries with the following properties:
        - OrganizationId   : String - The unique organization identifier
        - OrganizationName : String - The organization display name
        - Url              : String - The organization URL
        - Owner            : String - The organization owner display name
        - ExceptionType    : String - Error type if connection has issues
        - ErrorMessage     : String - Detailed error message if applicable
        - HasError         : Boolean - Whether this organization connection has
        errors

.EXAMPLE
    # Create PAT-based auth header and call with splatting
    $bearerHeader = @{ Authorization = "Bearer $env:AZDEVOPS_ACCESS_TOKEN" }
    $params = @{
        TenantId                           = 'YOUR_TENANT_ID_HERE'
        AdoBearerBasedAuthenticationHeader = $bearerHeader
    }
    Read-AdoTenantOrganizationConnections @params

.NOTES
    WARNING:
    This function uses an undocumented API endpoint that is not part of the
    officially supported Azure DevOps REST API. While Microsoft has sanctioned
    its use (see Developer Community link below), the endpoint may change or be
    removed without notice.

    Endpoints used:
    https://aexprodweu1.vsaex.visualstudio.com/_apis/EnterpriseCatalog/Organizations?tenantId={tenantId}

    Authentication:
      - Uses Bearer token authentication via header.

    API Status:
      - This endpoint is not part of the officially documented Azure DevOps REST
        API, however it is sanctioned by Microsoft for use as confirmed in
        Developer Community:
        https://developercommunity.visualstudio.com/t/Unable-to-list-DevOps-accounts-using-a-E/10669967

    Version : 1.0.1
    Author  : Jev - @devjevnl | https://www.devjev.nl
    Source  : https://github.com/thecloudexplorers/simply-scripted

.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines?wt.mc_id=DT-MVP-5005327
#>
function Read-AdoTenantOrganizationConnections {
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param (
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoBearerBasedAuthenticationHeader
    )

    $uri = "https://aexprodweu1.vsaex.visualstudio.com/_apis/EnterpriseCatalog/Organizations?tenantId=$TenantId"

    # Result collection
    $organizationCollection = [System.Collections.ArrayList]::new()

    # Use temp file approach: Invoke-WebRequest for CSV download
    $tempFile = $null
    try {
        $tempFile = New-TemporaryFile
        $invokeParams = @{
            Uri             = $uri
            Method          = 'GET'
            Headers         = $AdoBearerBasedAuthenticationHeader
            OutFile         = $tempFile
            UseBasicParsing = $true
            ErrorAction     = 'Stop'
        }

        <#
        1> $null is used to suppress output to console of the Success stream while ensuring the remaining streams
        are preserved for error handling.
        #>
        Invoke-RestMethod @invokeParams 1> $null

        # Basic token/HTML check
        $rawContent = Get-Content -Path $tempFile -Raw
        if ($rawContent -match '<html' -or $rawContent -match 'Sign In') {
            Write-Error 'Access denied or token expired. Verify authentication token.' -ErrorAction Stop
        }

        # Import CSV
        $csv = Import-Csv -Path $tempFile

        foreach ($row in $csv) {
            # Normalize property names with spaces; keep original logical mapping
            $orgId = $row.'Organization Id'
            $orgName = $row.'Organization Name'
            $orgUrl = $row.'Url'
            $orgOwner = $row.'Owner'
            $exceptionType = $row.'Exception Type'
            $errorMessage = $row.'Error Message'
            $hasError = [bool]([string]::IsNullOrWhiteSpace($exceptionType) -eq $false -or [string]::IsNullOrWhiteSpace($errorMessage) -eq $false)

            [void]$organizationCollection.Add([PSCustomObject]@{
                    OrganizationId   = $orgId
                    OrganizationName = $orgName
                    Url              = $orgUrl
                    Owner            = $orgOwner
                    ExceptionType    = $exceptionType
                    ErrorMessage     = $errorMessage
                    HasError         = $hasError
                })
        }

        return $organizationCollection
    } catch {
        Write-Error "Failed to retrieve tenant organization connections: $($_.Exception.Message)" -ErrorAction Stop
    } finally {
        if ($tempFile -and (Test-Path -Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
