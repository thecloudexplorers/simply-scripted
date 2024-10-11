# Replace Configuration Files Tokens

This pipeline is designed to replace tokens in configuration files with actual values
based on specific patterns. It checks out the necessary repositories, runs a PowerShell
script to perform the token replacements, and then publishes the modified configuration files as build artifacts.

## Triggers

- **None**: This pipeline does not have any automatic triggers. It must be manually triggered or invoked through another process.

## Conditions

- **None**: There are no special conditions set for this pipeline.

## Jobs

### Prepare Configuration Files Stage

This stage is responsible for preparing the configuration files by replacing the tokens.

#### Job: Replace Tokens in Configuration Files Step

- **Display Name**: Replace Tokens in Configuration Files
- **Tasks**:
  1. **Checkout Repositories**:
     - The primary repository and the `landing-zone-control-plane` repository are checked out.
  2. **Run PowerShell Script**:
     - **Task Type**: PowerShell@2
     - **Display Name**: Run replaceConfigurationFilesTokens.ps1
     - **Inputs**:
       - `targetType`: filePath
       - `showWarnings`: true
       - `pwsh`: true
       - `filePath`: $(rootRepoLocation)\powershell\replaceConfigurationFilesTokens.ps1
       - `arguments`:
         - `-RootRepoLocation "$(rootRepoLocation)"`
         - `-ConfigFilesRootFolder "$(configFilesRootFolder)"`
         - `-StartTokenPattern "#{"`
         - `-EndTokenPattern "}#"`
         - `-ExtractTokenValueFromConfigFileName`
         - `-PrefixForConfigFileNameWithTokenValue "env"`
         - `-TargetTokenNameForTokenValueFromConfigFileName "environment_acronym"`
  3. **Publish Build Artifacts**:
     - **Task Type**: PublishBuildArtifacts@1
     - **Inputs**:
       - `pathToPublish`: $(configFilesRootFolder)
       - `artifactName`: $(configFilesArtifactName)
