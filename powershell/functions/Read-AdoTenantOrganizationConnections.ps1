<#
.SYNOPSIS
    Reads and displays Azure DevOps organizations connected to an Entra ID tenant using the public API.

.DESCRIPTION
    This function uses the Azure DevOps EnterpriseCatalog API to download a CSV file
    listing all organizations connected to the specified Entra ID tenant.
    It parses the CSV and displays each organization's name, URL, and owner.
    Any organization with an error is flagged.

.PARAMETER TenantId
    The Entra ID (Azure AD) tenant ID used to scope the query.

.PARAMETER AccessToken
    A valid Azure DevOps Bearer token.

.EXAMPLE
    $orgListParams = @{
        TenantId    = "a74be31f-7904-4c43-8ef5-c82967c8e559"
        AccessToken = $token
    }

    Read-AdoTenantOrganizationConnections @orgListParams

.NOTES
    API: https://aexprodweu1.vsaex.visualstudio.com/_apis/EnterpriseCatalog/Organizations?tenantId={tenantId}

    Version     : 0.5.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
function Read-AdoTenantOrganizationConnections {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )

    $uri = "https://aexprodweu1.vsaex.visualstudio.com/_apis/EnterpriseCatalog/Organizations?tenantId=$TenantId"
    $headers = @{
        Authorization = "Bearer $AccessToken"
        Accept        = "text/csv"
    }

    try {
        # Download CSV to temp path
        $tempFile = New-TemporaryFile
        Invoke-WebRequest -Uri $uri -Headers $headers -OutFile $tempFile -UseBasicParsing

        # Read and normalize CSV
        $data = Import-Csv -Path $tempFile | ForEach-Object {
            $cleaned = @{}
            $_.PSObject.Properties | ForEach-Object {
                $key = $_.Name.Trim()
                $cleaned[$key] = $_.Value
            }

            [PSCustomObject]@{
                OrganizationId   = $cleaned['Organization Id']
                OrganizationName = $cleaned['Organization Name']
                Url              = $cleaned['Url']
                Owner            = $cleaned['Owner']
                ExceptionType    = $cleaned['Exception Type']
                ErrorMessage     = $cleaned['Error Message']
            }
        }

        Write-Host ""
        Write-Host "===== Azure DevOps Tenant Organization Connections ====="
        Write-Host ""

        Write-Host "Total Organizations Connected to Tenant: $($data.Count)"
        Write-Host ""

        foreach ($org in $data) {
            Write-Host "Organization : $($org.OrganizationName)"
            Write-Host "URL          : $($org.Url)"
            Write-Host "Owner        : $($org.Owner)"

            if ($org.ExceptionType -or $org.ErrorMessage) {
                Write-Host "Error        : $($org.ExceptionType) - $($org.ErrorMessage)"
            }

            Write-Host ""
        }

        Write-Host "Assessment complete.`n"

        # Clean up temp file
        Remove-Item -Path $tempFile -Force
    } catch {
        Write-Error "Failed to download or process CSV: $($_.Exception.Message)"
    }
}
