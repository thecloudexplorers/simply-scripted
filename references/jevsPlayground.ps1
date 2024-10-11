
$params = @{
    RootRepoLocation                               = "C:\dev\gh\thecloudexplorers\simply-scripted"
    ConfigFilesRootFolder                          = "C:\dev\gh\thecloudexplorers\simply-scripted\references\tnp"
    CustomOutputFolderPath                         = "C:\Output"
    StartTokenPattern                              = "#{"
    EndTokenPattern                                = "}#"
    ExtractTokenValueFromConfigFileName            = $true
    PrefixForConfigFileNameWithTokenValue          = "env"
    TargetTokenNameForTokenValueFromConfigFileName = "environment_acronym"
}
.\powershell\replaceConfigurationFilesTokens.ps1 @params

Write-Host "Stopped here!!"
