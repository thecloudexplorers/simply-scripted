#Requires -PSEdition Core
<#
    .SYNOPSIS
    Creates a new Azure DevOps project

    .DESCRIPTION
    This function creates an azure DevOps project in the specified organization with source control type Git and
    process template tye set to Agile for the Boards.

    .PARAMETER AdoApiUri
    Ado Api uri of Azure DevOps, unless modified by microsoft this should be https://dev.azure.com/

    .PARAMETER AdoOrganizationName
    Name of the concerning Azure DevOps organization

    .PARAMETER AdoProjectName
    Desired project name

    .PARAMETER AdoProjectDescription
    A description for the desired project

    .PARAMETER AdoProjectSourceControlType
    Source control type, default is set to Git, option to override it to TFVC

    .PARAMETER AdoAuthenticationHeader
    Azure DevOps authentication header based on PAT token

    .EXAMPLE
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Basic ' + $authToken
    }

    $inputArgs = @{
        AdoApiUri = "https://dev.azure.com/"
        AdoOrganizationName = "my-organization"
        AdoProjectName = "my-project-name"
        AdoProjectDescription "Lorem ipsum dolor sit amet, consectetur adipiscing eli."
        AdoAuthenticationHeader = $authHeader
    }

    New-AdoProject @inputArgs

    .NOTES
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>

function New-AdoProject {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoApiUri,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoOrganizationName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoProjectName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.String] $AdoProjectDescription,

        [ValidateNotNullOrEmpty()]
        [ValidateSet('Basic', 'Agile', 'Scrum', 'CMMI')]
        [System.String] $AdoProjectProcessTemplate,

        [ValidateNotNullOrEmpty()]
        [ValidateSet("Git", "TFVC")]
        [System.String] $AdoProjectSourceControlType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable] $AdoAuthenticationHeader
    )

    # getting all available process templates, a process template id is required for creating projects
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/core/processes/get
    # GET https://dev.azure.com/{organization}/_apis/process/processes/{processId}?api-version=7.1-preview.1
    $processesApiUri = $AdoApiUri + $AdoOrganizationName + "/_apis/process/processes?api-version=7.1-preview.1"
    $processesApiResponse = Invoke-RestMethod -Uri $processesApiUri -Method 'Get' -Headers $AdoAuthenticationHeader

    $processTemplate = $processesApiResponse.value | Where-Object { $_.name -eq $AdoProjectProcessTemplate }

    $projectObject = @{
        name         = $AdoProjectName
        description  = $AdoProjectDescription
        capabilities = @{
            versioncontrol  = @{
                sourceControlType = $AdoProjectSourceControlType
            }
            processTemplate = @{
                templateTypeId = $processTemplate.id
            }
        }
    }

    $projectJsonObject = $projectObject | ConvertTo-Json

    # create azure devops project
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/get
    # POST https://dev.azure.com/{organization}/_apis/projects?api-version=7.1-preview.4
    $projectsApiUri = $AdoApiUri + $AdoOrganizationName + "/_apis/projects/?api-version=7.1-preview.4"
    $projectsApiResponse = Invoke-RestMethod -Uri $projectsApiUri -Method 'Post' -Headers $AdoAuthenticationHeader -Body $projectJsonObject
    Write-Information -MessageData " Project creation queued for [$AdoProjectName] project"

    try {

        # project creation is processed by Microsoft via a queue, query the queue url returned from the creation Api call
        # to query the queue status and create a while loop waiting for the queue to be processed
        $projectCreationStatus = Invoke-RestMethod -Uri $projectsApiResponse.url -Method 'Get' -Headers $AdoAuthenticationHeader

        Write-Information -MessageData "  Queue is being processed"
        while ($projectCreationStatus.status -eq "inProgress" -or $projectCreationStatus.status -eq "notSet" -or $projectCreationStatus.status -eq "queued") {
            # sleeping 3 seconds to wait for the queue to complete
            $sleepTime = 3
            Write-Information -MessageData "  Sleeping for [$sleepTime] seconds"
            Start-Sleep -Seconds $sleepTime

            Write-Information -MessageData "  Updating queue"
            $projectCreationStatus = $null
            $projectCreationStatus = Invoke-RestMethod -Uri $projectsApiResponse.url -Method 'Get' -Headers $AdoAuthenticationHeader
        }

        if ($projectCreationStatus.status -ne 'succeeded') {
            Write-Error -Message " Creating a new Azure DevOps project [$AdoProjectName] failed with status [$($projectCreationStatus.status)] " -ErrorAction Stop
        } else {
            Write-Information -MessageData " Project has been created `n"
        }
    } catch {
        Throw $_
    }
}
