#Requires -PSEdition Core

<#
    .SYNOPSIS
    Converts Azure DevOps YAML pipelines to JSON format

    .DESCRIPTION
    This function takes an Azure DevOps YAML pipeline as input and converts it 
    into a JSON file. It accepts either a file path to a YAML file or direct 
    YAML string content, parses the YAML structure, and outputs the equivalent 
    JSON representation. This facilitates migration, analysis, and integration 
    scenarios involving Azure DevOps pipelines.

    .PARAMETER YamlFilePath
    The path to the YAML pipeline file to convert. Cannot be used together 
    with YamlContent parameter.

    .PARAMETER YamlContent
    Direct YAML content as a string to convert. Cannot be used together 
    with YamlFilePath parameter.

    .PARAMETER OutputPath
    Optional path where the JSON file should be saved. If not specified, 
    the output will be saved to the same directory as the input file with 
    a .json extension, or to the current directory if YamlContent is used.

    .PARAMETER OutputToConsole
    Switch parameter to output the JSON content to the console instead 
    of saving to a file.

    .EXAMPLE
    Convert-AdoYamlToJson -YamlFilePath "C:\pipelines\azure-pipeline.yml"

    Converts the YAML file to JSON and saves it as azure-pipeline.json in the same directory.

    .EXAMPLE
    Convert-AdoYamlToJson -YamlFilePath "C:\pipelines\azure-pipeline.yml" -OutputPath "C:\output\pipeline.json"

    Converts the YAML file to JSON and saves it to the specified output path.

    .EXAMPLE
    $yamlContent = @"
    trigger:
      - main
    pool:
      vmImage: 'ubuntu-latest'
    steps:
      - script: echo Hello World
    "@
    Convert-AdoYamlToJson -YamlContent $yamlContent -OutputToConsole

    Converts the YAML content string to JSON and displays it in the console.

    .EXAMPLE
    Convert-AdoYamlToJson -YamlContent $yamlContent -OutputPath "C:\output\pipeline.json"

    Converts the YAML content string to JSON and saves it to the specified file.

    .NOTES
    Version     : 1.0.0
    Author      : Jev - @devjevnl | https://www.devjev.nl
    Source      : https://github.com/thecloudexplorers/simply-scripted
#>
function Convert-AdoYamlToJson {
    [CmdletBinding(DefaultParameterSetName = 'FromFile')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'FromFile')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "File does not exist: $_"
            }
            if ($_ -notmatch '\.(yml|yaml)$') {
                throw "File must have .yml or .yaml extension: $_"
            }
            return $true
        })]
        [System.String] $YamlFilePath,

        [Parameter(Mandatory, ParameterSetName = 'FromContent')]
        [ValidateNotNullOrEmpty()]
        [System.String] $YamlContent,

        [Parameter(ParameterSetName = 'FromFile')]
        [Parameter(ParameterSetName = 'FromContent')]
        [ValidateNotNullOrEmpty()]
        [System.String] $OutputPath,

        [Parameter(ParameterSetName = 'FromFile')]
        [Parameter(ParameterSetName = 'FromContent')]
        [System.Management.Automation.SwitchParameter] $OutputToConsole
    )

    try {
        Write-Host "Starting Azure DevOps YAML to JSON conversion"

        # Get YAML content based on parameter set
        if ($PSCmdlet.ParameterSetName -eq 'FromFile') {
            Write-Host " Reading YAML file: $YamlFilePath"
            $yamlText = Get-Content -Path $YamlFilePath -Raw -Encoding UTF8
            $sourceFileName = [System.IO.Path]::GetFileNameWithoutExtension($YamlFilePath)
            $sourceDirectory = [System.IO.Path]::GetDirectoryName($YamlFilePath)
        } else {
            Write-Host " Processing YAML content from string parameter"
            $yamlText = $YamlContent
            $sourceFileName = "pipeline"
            $sourceDirectory = Get-Location
        }

        if ([string]::IsNullOrWhiteSpace($yamlText)) {
            throw "YAML content is empty or contains only whitespace"
        }

        # Parse YAML to PowerShell object
        Write-Host " Parsing YAML content to PowerShell object"
        $parsedObject = ConvertFrom-Yaml -YamlText $yamlText

        # Convert to JSON
        Write-Host " Converting to JSON format"
        $jsonContent = $parsedObject | ConvertTo-Json -Depth 10

        # Handle output
        if ($OutputToConsole) {
            Write-Host " Outputting JSON to console"
            Write-Output $jsonContent
        } else {
            # Determine output path
            if ([string]::IsNullOrWhiteSpace($OutputPath)) {
                $OutputPath = Join-Path $sourceDirectory "$sourceFileName.json"
            }

            Write-Host " Saving JSON to file: $OutputPath"
            
            # Ensure output directory exists
            $outputDirectory = [System.IO.Path]::GetDirectoryName($OutputPath)
            if (-not (Test-Path $outputDirectory)) {
                New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
            }

            # Save to file with UTF8 encoding
            $jsonContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
            Write-Host " Conversion completed successfully"
            Write-Host " Output saved to: $OutputPath"
        }

    } catch {
        Write-Error "An error occurred during YAML to JSON conversion: $($_.Exception.Message)" -ErrorAction Stop
    }
}

<#
    .SYNOPSIS
    Internal helper function to convert YAML text to PowerShell objects

    .DESCRIPTION
    This function implements a basic YAML parser for Azure DevOps pipeline YAML files.
    It handles common YAML structures including scalars, lists, and dictionaries.

    .PARAMETER YamlText
    The YAML text content to parse

    .NOTES
    This is an internal function that provides YAML parsing without external dependencies.
#>
function ConvertFrom-Yaml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $YamlText
    )

    try {
        $lines = $YamlText -split "`r?`n"
        $result = @{}
        
        # Simple stack using ordered dictionary
        $stack = [System.Collections.Generic.List[PSObject]]::new()
        $stack.Add([PSCustomObject]@{ 
            Object = $result
            Indent = -1
            IsArray = $false
        })

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith('#')) {
                continue
            }
            
            # Calculate indentation
            $indent = 0
            for ($j = 0; $j -lt $line.Length; $j++) {
                if ($line[$j] -eq ' ') { 
                    $indent++ 
                } elseif ($line[$j] -eq "`t") { 
                    $indent += 4 
                } else { 
                    break 
                }
            }
            
            $trimmedLine = $line.Trim()
            
            # Pop context for dedentation
            while ($stack.Count -gt 1 -and $stack[$stack.Count - 1].Indent -ge $indent) {
                $stack.RemoveAt($stack.Count - 1)
            }
            
            $currentContext = $stack[$stack.Count - 1]
            $currentObject = $currentContext.Object
            
            # Handle array items
            if ($trimmedLine.StartsWith('- ')) {
                $itemText = $trimmedLine.Substring(2).Trim()
                
                # Ensure we have an array
                if (-not $currentContext.IsArray) {
                    $arrayList = [System.Collections.ArrayList]::new()
                    
                    # Replace the current object with the array
                    if ($stack.Count -gt 1) {
                        $parent = $stack[$stack.Count - 2]
                        $key = $currentContext.Key
                        if ($key) {
                            $parent.Object[$key] = $arrayList
                        }
                    }
                    
                    $currentContext.Object = $arrayList
                    $currentContext.IsArray = $true
                    $currentObject = $arrayList
                }
                
                if ([string]::IsNullOrEmpty($itemText) -or $itemText.Contains(':')) {
                    # Complex array item
                    $newItem = @{}
                    [void]$currentObject.Add($newItem)
                    
                    # Push the new item to the stack so subsequent lines can add to it
                    $stack.Add([PSCustomObject]@{
                        Object = $newItem
                        Indent = $indent
                        IsArray = $false
                        Key = $null
                    })
                    
                    # Handle inline key-value
                    if ($itemText.Contains(':') -and $itemText -match '^([^:]+):\s*(.*)$') {
                        $key = $Matches[1].Trim()
                        $value = $Matches[2].Trim()
                        
                        if ([string]::IsNullOrEmpty($value)) {
                            $newItem[$key] = @{}
                            $stack.Add([PSCustomObject]@{
                                Object = $newItem[$key]
                                Indent = $indent
                                IsArray = $false
                                Key = $key
                            })
                        } else {
                            $newItem[$key] = Convert-YamlValue $value
                        }
                    }
                } else {
                    # Simple array item
                    [void]$currentObject.Add((Convert-YamlValue $itemText))
                }
            }
            # Handle key-value pairs
            elseif ($trimmedLine -match '^([^:]+):\s*(.*)$') {
                $key = $Matches[1].Trim()
                $value = $Matches[2].Trim()
                
                # Make sure we're not trying to add key-value pairs to an array
                if ($currentContext.IsArray) {
                    continue
                }
                
                if ([string]::IsNullOrEmpty($value)) {
                    # Complex value
                    $currentObject[$key] = @{}
                    $stack.Add([PSCustomObject]@{
                        Object = $currentObject[$key]
                        Indent = $indent
                        IsArray = $false
                        Key = $key
                    })
                } else {
                    # Simple value
                    $currentObject[$key] = Convert-YamlValue $value
                }
            }
        }
        
        # Convert ArrayLists to arrays for JSON serialization
        return Convert-ArrayListsToArrays $result
        
    } catch {
        throw "Failed to parse YAML: $($_.Exception.Message)"
    }
}

<#
    .SYNOPSIS
    Helper function to convert ArrayLists to regular arrays for proper JSON serialization

    .PARAMETER Object
    The object to process
#>
function Convert-ArrayListsToArrays {
    param($Object)
    
    if ($Object -is [System.Collections.ArrayList]) {
        $array = @()
        foreach ($item in $Object) {
            $array += Convert-ArrayListsToArrays $item
        }
        return $array
    }
    elseif ($Object -is [hashtable]) {
        $newHash = @{}
        foreach ($key in $Object.Keys) {
            $newHash[$key] = Convert-ArrayListsToArrays $Object[$key]
        }
        return $newHash
    }
    else {
        return $Object
    }
}

<#
    .SYNOPSIS
    Helper function to convert YAML values to appropriate PowerShell types

    .PARAMETER Value
    The YAML value to convert
#>
function Convert-YamlValue {
    param([string] $Value)
    
    if ([string]::IsNullOrEmpty($Value)) { return $null }
    
    # Handle quoted strings
    if (($Value.StartsWith('"') -and $Value.EndsWith('"')) -or 
        ($Value.StartsWith("'") -and $Value.EndsWith("'"))) {
        return $Value.Substring(1, $Value.Length - 2)
    }
    
    # Handle booleans and null
    switch ($Value.ToLower()) {
        'true' { return $true }
        'false' { return $false }
        'null' { return $null }
        '~' { return $null }
    }
    
    # Handle numbers
    if ($Value -match '^\d+$') {
        try {
            return [int]$Value
        } catch {
            return $Value
        }
    }
    if ($Value -match '^\d+\.\d+$') {
        try {
            return [double]$Value
        } catch {
            return $Value
        }
    }
    
    # Return as string
    return $Value
}